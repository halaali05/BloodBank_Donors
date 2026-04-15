const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { publicCallableOpts } = require("./callable_config");

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please log in first");
  }
  return request.auth.uid;
}

async function requireRole(uid, expectedRole) {
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User not found");
  }
  const userData = userSnap.data() || {};
  if (userData.role !== expectedRole) {
    throw new HttpsError(
      "permission-denied",
      `Only ${expectedRole}s can perform this action`,
    );
  }
  return userData;
}

async function getRequest(requestId) {
  const reqSnap = await db.collection("requests").doc(requestId).get();
  if (!reqSnap.exists) {
    throw new HttpsError("not-found", "Request not found");
  }
  const raw = reqSnap.data();
  const d = raw && typeof raw === "object" ? raw : {};
  return { id: reqSnap.id, ...d };
}

function parseAppointmentInstant(appointmentAt) {
  if (appointmentAt == null) return null;
  if (typeof appointmentAt === "number" && Number.isFinite(appointmentAt)) {
    const d = new Date(appointmentAt);
    return isNaN(d.getTime()) ? null : d;
  }
  if (typeof appointmentAt === "string") {
    const s = appointmentAt.trim();
    if (!s) return null;
    if (/^\d+$/.test(s)) {
      const n = Number(s);
      if (!Number.isFinite(n)) return null;
      const d = new Date(n);
      return isNaN(d.getTime()) ? null : d;
    }
    const d = new Date(s);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 1. scheduleDonorAppointment
// ---------------------------------------------------------------------------
exports.scheduleDonorAppointment = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const callerUid = requireAuth(request);
      await requireRole(callerUid, "hospital");

      const data = request.data || {};
      const { requestId, donorId, appointmentAt } = data;

      if (!requestId || typeof requestId !== "string")
        throw new HttpsError("invalid-argument", "requestId is required");
      if (!donorId || typeof donorId !== "string")
        throw new HttpsError("invalid-argument", "donorId is required");

      const appointmentDate = parseAppointmentInstant(appointmentAt);
      if (!appointmentDate)
        throw new HttpsError(
          "invalid-argument",
          "appointmentAt must be epoch milliseconds (number) or a valid ISO date string",
        );
      if (appointmentDate.getTime() < Date.now() - 30_000)
        throw new HttpsError(
          "invalid-argument",
          "Appointment date must be in the future",
        );

      const req = await getRequest(requestId);

      if (req.bloodBankId !== callerUid)
        throw new HttpsError(
          "permission-denied",
          "You can only manage donors for your own requests",
        );

      const donorResponseRef = db
        .collection("requests")
        .doc(requestId)
        .collection("donorResponses")
        .doc(donorId);

      const donorResponseSnap = await donorResponseRef.get();
      if (!donorResponseSnap.exists)
        throw new HttpsError(
          "not-found",
          "Donor has not accepted this request",
        );

      const d = donorResponseSnap.data() || {};
      const inviteStatus = String(d.status || "").toLowerCase();
      if (inviteStatus !== "accepted") {
        throw new HttpsError(
          "failed-precondition",
          "Donor has not accepted this request",
        );
      }

      const pipeline = String(d.processStatus || "").toLowerCase();
      const terminal = new Set(["tested", "donated", "restricted"]);
      if (terminal.has(pipeline)) {
        throw new HttpsError(
          "failed-precondition",
          `Donor is already in status: ${pipeline}`,
        );
      }

      const isReschedule = pipeline === "scheduled";

      await donorResponseRef.update({
        processStatus: "scheduled",
        appointmentAt: admin.firestore.Timestamp.fromDate(appointmentDate),
        scheduledAt: admin.firestore.FieldValue.serverTimestamp(),
        scheduledBy: callerUid,
      });

      // FCM notification to donor
      try {
        const donorSnap = await db.collection("users").doc(donorId).get();
        if (donorSnap.exists) {
          const du = donorSnap.data() || {};
          const fcmToken = du.fcmToken;
          if (typeof fcmToken === "string" && fcmToken.trim()) {
            const dateStr = appointmentDate.toLocaleDateString("en-US", {
              weekday: "short",
              month: "short",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            });
            await admin.messaging().send({
              token: fcmToken.trim(),
              notification: {
                title: isReschedule
                  ? "📅 Appointment updated"
                  : "📅 Appointment scheduled",
                body: `${req.bloodBankName || "The blood bank"} scheduled your ${req.bloodType || ""} donation for ${dateStr}`,
              },
              data: {
                type: "appointment_scheduled",
                requestId: String(requestId),
                appointmentAt: appointmentDate.toISOString(),
              },
            });
          }
        }
      } catch (e) {
        console.warn("FCM failed (scheduleDonorAppointment):", e.message);
      }

      return {
        success: true,
        message: isReschedule ? "Appointment updated" : "Appointment scheduled",
      };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("[scheduleDonorAppointment] unhandled:", e);
      throw new HttpsError(
        "internal",
        "Schedule failed. Please try again or contact support.",
      );
    }
  },
);

// ---------------------------------------------------------------------------
// 2. saveMedicalReport
// ---------------------------------------------------------------------------
exports.saveMedicalReport = onCall(publicCallableOpts, async (request) => {
  try {
    const callerUid = requireAuth(request);
    await requireRole(callerUid, "hospital");

    const {
      requestId,
      donorId,
      status,
      restrictionReason,
      notes,
      reportFileUrl,
      canDonateAgainAt,
    } = request.data;

    if (!requestId || typeof requestId !== "string")
      throw new HttpsError("invalid-argument", "requestId is required");
    if (!donorId || typeof donorId !== "string")
      throw new HttpsError("invalid-argument", "donorId is required");
    if (status !== "donated" && status !== "restricted")
      throw new HttpsError(
        "invalid-argument",
        'status must be "donated" or "restricted"',
      );
    if (
      status === "restricted" &&
      (!restrictionReason || restrictionReason.trim() === "")
    )
      throw new HttpsError(
        "invalid-argument",
        "restrictionReason is required when status is restricted",
      );

    let canDonateAgainDate = null;
    if (canDonateAgainAt) {
      canDonateAgainDate = new Date(canDonateAgainAt);
      if (isNaN(canDonateAgainDate.getTime()))
        throw new HttpsError(
          "invalid-argument",
          "canDonateAgainAt must be a valid ISO date string",
        );
    }

    const req = await getRequest(requestId);

    if (req.bloodBankId !== callerUid)
      throw new HttpsError(
        "permission-denied",
        "You can only manage donors for your own requests",
      );

    const donorResponseRef = db
      .collection("requests")
      .doc(requestId)
      .collection("donorResponses")
      .doc(donorId);

    const donorResponseSnap = await donorResponseRef.get();
    if (!donorResponseSnap.exists)
      throw new HttpsError("not-found", "Donor has not accepted this request");

    const reportData = {
      requestId,
      donorId,
      bloodBankId: callerUid,
      bloodBankName: req.bloodBankName || "",
      bloodType: req.bloodType || "",
      isUrgent: req.isUrgent || false,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (restrictionReason)
      reportData.restrictionReason = restrictionReason.trim();
    if (notes && notes.trim()) reportData.notes = notes.trim();
    if (reportFileUrl) reportData.reportFileUrl = reportFileUrl;
    if (canDonateAgainDate)
      reportData.canDonateAgainAt =
        admin.firestore.Timestamp.fromDate(canDonateAgainDate);

    const reportRef = db.collection("medicalReports").doc();
    const batch = db.batch();

    batch.set(reportRef, reportData);

    batch.update(donorResponseRef, {
      processStatus: status,
      reportId: reportRef.id,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const donorRef = db.collection("users").doc(donorId);
    if (status === "restricted" && canDonateAgainDate) {
      batch.update(donorRef, {
        restrictedUntil: admin.firestore.Timestamp.fromDate(canDonateAgainDate),
        restrictionReason: restrictionReason ? restrictionReason.trim() : "",
      });
    } else if (status === "donated") {
      batch.update(donorRef, {
        restrictedUntil: admin.firestore.FieldValue.delete(),
        restrictionReason: admin.firestore.FieldValue.delete(),
        lastDonatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // FCM notification to donor
    try {
      const donorSnap = await db.collection("users").doc(donorId).get();
      if (donorSnap.exists) {
        const du = donorSnap.data() || {};
        const fcmToken = du.fcmToken;
        if (typeof fcmToken === "string" && fcmToken.trim()) {
          const title =
            status === "donated"
              ? "🩸 Donation Confirmed!"
              : "⚠️ Donation Result";
          const body =
            status === "donated"
              ? `${req.bloodBankName || "The blood bank"} confirmed your ${req.bloodType || ""} donation. Thank you!`
              : `${req.bloodBankName || "The blood bank"} has a note regarding your ${req.bloodType || ""} donation. Check your profile.`;
          await admin.messaging().send({
            token: fcmToken.trim(),
            notification: { title, body },
            data: {
              type: "medical_report_saved",
              requestId: String(requestId),
              reportId: String(reportRef.id),
              status: String(status),
            },
          });
        }
      }
    } catch (e) {
      console.warn("FCM failed (saveMedicalReport):", e.message);
    }

    return { success: true, reportId: reportRef.id };
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error("[saveMedicalReport] unhandled:", e);
    throw new HttpsError(
      "internal",
      "Failed to save report. Please try again.",
    );
  }
});

// ---------------------------------------------------------------------------
// 3. getDonationHistory
// ---------------------------------------------------------------------------
exports.getDonationHistory = onCall(publicCallableOpts, async (request) => {
  try {
    const callerUid = requireAuth(request);
    await requireRole(callerUid, "donor");

    const snapshot = await db
      .collection("medicalReports")
      .where("donorId", "==", callerUid)
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();

    const toISO = (ts) => {
      if (!ts) return null;
      if (ts.toDate) return ts.toDate().toISOString();
      if (ts instanceof Date) return ts.toISOString();
      return null;
    };

    const reports = snapshot.docs.map((doc) => {
      const d = doc.data();
      return {
        id: doc.id,
        requestId: d.requestId || "",
        bloodBankId: d.bloodBankId || "",
        bloodBankName: d.bloodBankName || "",
        bloodType: d.bloodType || "",
        isUrgent: d.isUrgent || false,
        status: d.status || "donated",
        restrictionReason: d.restrictionReason || null,
        notes: d.notes || null,
        reportFileUrl: d.reportFileUrl || null,
        canDonateAgainAt: toISO(d.canDonateAgainAt),
        createdAt: toISO(d.createdAt),
      };
    });

    return { reports };
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error("[getDonationHistory] unhandled:", e);
    throw new HttpsError("internal", "Failed to fetch donation history.");
  }
});

// ---------------------------------------------------------------------------
// 4. getRequestDonorResponses
// ---------------------------------------------------------------------------
exports.getRequestDonorResponses = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const callerUid = requireAuth(request);
      await requireRole(callerUid, "hospital");

      const { requestId } = request.data || {};
      if (!requestId || typeof requestId !== "string")
        throw new HttpsError("invalid-argument", "requestId is required");

      const req = await getRequest(requestId);
      if (req.bloodBankId !== callerUid)
        throw new HttpsError(
          "permission-denied",
          "You can only view donors for your own requests",
        );

      const snapshot = await db
        .collection("requests")
        .doc(requestId)
        .collection("donorResponses")
        .get();

      const toMillis = (ts) => {
        if (!ts) return null;
        if (ts.toMillis) return ts.toMillis();
        if (ts instanceof Date) return ts.getTime();
        return null;
      };

      const accepted = [];
      const rejected = [];

      for (const doc of snapshot.docs) {
        const d = doc.data() || {};
        const status = String(d.status || "").toLowerCase();

        // Fetch donor name/email from users collection
        let fullName = d.fullName || "";
        let email = d.email || "";
        if (!fullName || !email) {
          try {
            const donorSnap = await db.collection("users").doc(doc.id).get();
            if (donorSnap.exists) {
              const du = donorSnap.data() || {};
              fullName = fullName || du.fullName || du.name || "Donor";
              email = email || du.email || "";
            }
          } catch (_) {}
        }

        const entry = {
          donorId: doc.id,
          fullName: fullName || "Donor",
          email,
          processStatus: d.processStatus || "accepted",
          appointmentAtMillis: toMillis(d.appointmentAt),
          reportId: d.reportId || null,
        };

        if (status === "accepted") accepted.push(entry);
        else if (status === "rejected") rejected.push(entry);
      }

      return { accepted, rejected };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("[getRequestDonorResponses] unhandled:", e);
      throw new HttpsError("internal", "Failed to fetch donor responses.");
    }
  },
);
