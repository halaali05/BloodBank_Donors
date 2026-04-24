const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { publicCallableOpts } = require("./callable_config");
const { scheduleRef } = require("./donation_schedule");
const { createAndBroadcastFollowUpRequest } = require("./src/requests");

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
  const role = String(userData.role || "")
    .trim()
    .toLowerCase();
  const want = String(expectedRole || "")
    .trim()
    .toLowerCase();
  if (role !== want) {
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

const STANDARD_BLOOD_TYPES = new Set([
  "A+",
  "A-",
  "B+",
  "B-",
  "AB+",
  "AB-",
  "O+",
  "O-",
]);

function normalizeStandardBloodType(s) {
  if (s == null) return null;
  const t = String(s).trim().toUpperCase().replace(/\s+/g, "");
  if (!t) return null;
  return STANDARD_BLOOD_TYPES.has(t) ? t : null;
}

function serializeMedicalReportDoc(doc) {
  const d = doc.data() || {};
  const toISO = (ts) => {
    if (!ts) return null;
    if (ts.toDate) return ts.toDate().toISOString();
    if (ts instanceof Date) return ts.toISOString();
    return null;
  };
  return {
    id: doc.id,
    requestId: d.requestId || "",
    bloodBankId: d.bloodBankId || "",
    bloodBankName: d.bloodBankName || "",
    bloodType: d.bloodType || "",
    isUrgent: !!d.isUrgent,
    status: d.status || "",
    restrictionReason: d.restrictionReason || null,
    notes: d.notes || null,
    reportFileUrl: d.reportFileUrl || null,
    canDonateAgainAt: toISO(d.canDonateAgainAt),
    appointmentAt: toISO(d.appointmentAt),
    createdAt: toISO(d.createdAt),
  };
}

function parseAppointmentInstant(appointmentAt) {
  if (appointmentAt == null) return null;

  if (
    typeof appointmentAt === "object" &&
    typeof appointmentAt.toMillis === "function"
  ) {
    const d = appointmentAt.toDate();
    return d instanceof Date && !isNaN(d.getTime()) ? d : null;
  }

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

/** Epoch ms for donorResponses.appointmentAt if set (any supported Firestore shape). */
function donorResponseAppointmentMillis(d) {
  if (!d || typeof d !== "object") return null;
  const apt = d.appointmentAt;
  if (apt == null) return null;
  if (typeof apt.toMillis === "function") return apt.toMillis();
  if (apt instanceof Date) return apt.getTime();
  if (typeof apt === "number" && Number.isFinite(apt)) return apt;
  if (typeof apt === "string") {
    const p = Date.parse(apt);
    return isNaN(p) ? null : p;
  }
  if (
    typeof apt === "object" &&
    typeof apt._seconds === "number" &&
    Number.isFinite(apt._seconds)
  ) {
    return apt._seconds * 1000 + Math.floor((apt._nanoseconds || 0) / 1e6);
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

      if (!requestId || typeof requestId !== "string") {
        throw new HttpsError("invalid-argument", "requestId is required");
      }

      if (!donorId || typeof donorId !== "string") {
        throw new HttpsError("invalid-argument", "donorId is required");
      }

      const appointmentDate = parseAppointmentInstant(appointmentAt);
      if (!appointmentDate) {
        throw new HttpsError(
          "invalid-argument",
          "appointmentAt must be epoch milliseconds (number) or a valid ISO date string",
        );
      }

      if (appointmentDate.getTime() < Date.now() - 30000) {
        throw new HttpsError(
          "invalid-argument",
          "Appointment date must be in the future",
        );
      }

      const req = await getRequest(requestId);

      if (req.bloodBankId !== callerUid) {
        throw new HttpsError(
          "permission-denied",
          "You can only manage donors for your own requests",
        );
      }

      const donorResponseRef = db
        .collection("requests")
        .doc(requestId)
        .collection("donorResponses")
        .doc(donorId);

      const donorResponseSnap = await donorResponseRef.get();
      if (!donorResponseSnap.exists) {
        throw new HttpsError(
          "not-found",
          "Donor has not accepted this request",
        );
      }

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
        appointmentStatus: "scheduled",
        appointmentAt: admin.firestore.Timestamp.fromDate(appointmentDate),
        scheduledAt: admin.firestore.FieldValue.serverTimestamp(),
        scheduledBy: callerUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        rescheduleReason: admin.firestore.FieldValue.delete(),
        reschedulePreferredAt: admin.firestore.FieldValue.delete(),
        rescheduleRequestedAt: admin.firestore.FieldValue.delete(),
      });

      // Ensures donation history can load this request without collection-group queries
      // (covers donors who accepted before donorAcceptedRequestIds existed).
      await db
        .collection("users")
        .doc(donorId)
        .set(
          {
            donorAcceptedRequestIds:
              admin.firestore.FieldValue.arrayUnion(requestId),
          },
          { merge: true },
        );

      try {
        const donorSnap = await db.collection("users").doc(donorId).get();
        if (donorSnap.exists) {
          const du = donorSnap.data() || {};
          const fcmToken = du.fcmToken;
          const dateStr = appointmentDate.toLocaleDateString("en-US", {
            weekday: "short",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          });

          const notifTitle = isReschedule
            ? "📅 Appointment updated"
            : "📅 Appointment scheduled";

          const notifBody = `${
            req.bloodBankName || "The blood bank"
          } scheduled your ${req.bloodType || ""} donation for ${dateStr}`;

          const notifRef = db
            .collection("notifications")
            .doc(donorId)
            .collection("user_notifications")
            .doc();

          await notifRef.set({
            title: notifTitle,
            body: notifBody,
            type: "appointment_scheduled",
            requestId: String(requestId),
            appointmentAt: appointmentDate.toISOString(),
            isRead: false,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          if (typeof fcmToken === "string" && fcmToken.trim()) {
            await admin.messaging().send({
              token: fcmToken.trim(),
              notification: { title: notifTitle, body: notifBody },
              data: {
                type: "appointment_scheduled",
                requestId: String(requestId),
                appointmentAt: appointmentDate.toISOString(),
              },
            });
          }
        }
      } catch (e) {
        console.warn(
          "Notification or FCM failed (scheduleDonorAppointment):",
          e.message || e,
        );
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
// 1b. requestAppointmentReschedule (donor — back to pending + prefs for bank)
// ---------------------------------------------------------------------------
exports.requestAppointmentReschedule = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const callerUid = requireAuth(request);
      await requireRole(callerUid, "donor");

      const data = request.data || {};
      let { requestId, reason, preferredAppointmentAt } = data;

      if (typeof requestId === "number" && Number.isFinite(requestId)) {
        requestId = String(requestId);
      }
      if (!requestId || typeof requestId !== "string") {
        throw new HttpsError("invalid-argument", "requestId is required");
      }

      const reasonStr =
        typeof reason === "string"
          ? reason.trim()
          : String(reason || "").trim();
      if (reasonStr.length < 3) {
        throw new HttpsError(
          "invalid-argument",
          "Please enter a reason (at least 3 characters).",
        );
      }

      const preferredDate = parseAppointmentInstant(preferredAppointmentAt);
      if (!preferredDate) {
        throw new HttpsError(
          "invalid-argument",
          "preferredAppointmentAt must be epoch milliseconds or a valid date string",
        );
      }

      if (preferredDate.getTime() < Date.now() - 120000) {
        throw new HttpsError(
          "invalid-argument",
          "Preferred date and time must be in the future",
        );
      }

      const donorResponseRef = db
        .collection("requests")
        .doc(requestId)
        .collection("donorResponses")
        .doc(callerUid);

      const donorResponseSnap = await donorResponseRef.get();
      if (!donorResponseSnap.exists) {
        throw new HttpsError(
          "not-found",
          "You have not responded to this request",
        );
      }

      const d = donorResponseSnap.data() || {};
      const inviteStatus = String(d.status || "").toLowerCase();
      if (inviteStatus !== "accepted") {
        throw new HttpsError(
          "failed-precondition",
          "Only accepted donors can request a reschedule",
        );
      }

      const pipeline = String(d.processStatus || "").toLowerCase();
      const terminal = new Set(["tested", "donated", "restricted"]);
      if (terminal.has(pipeline)) {
        throw new HttpsError(
          "failed-precondition",
          "Cannot reschedule at this stage of your donation",
        );
      }
      const hasBankAppointment = donorResponseAppointmentMillis(d) != null;
      if (!hasBankAppointment) {
        throw new HttpsError(
          "failed-precondition",
          "You can only reschedule after an appointment has been scheduled for you",
        );
      }

      await donorResponseRef.update({
        processStatus: "accepted",
        appointmentAt: admin.firestore.FieldValue.delete(),
        scheduledAt: admin.firestore.FieldValue.delete(),
        scheduledBy: admin.firestore.FieldValue.delete(),
        rescheduleReason: reasonStr,
        reschedulePreferredAt:
          admin.firestore.Timestamp.fromDate(preferredDate),
        rescheduleRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, message: "Reschedule request sent" };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("[requestAppointmentReschedule] unhandled:", e);
      throw new HttpsError(
        "internal",
        "Could not send reschedule request. Please try again.",
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
      confirmedBloodType,
      isPermanentBlock,
    } = request.data || {};

    if (!requestId || typeof requestId !== "string") {
      throw new HttpsError("invalid-argument", "requestId is required");
    }

    if (!donorId || typeof donorId !== "string") {
      throw new HttpsError("invalid-argument", "donorId is required");
    }

    const normalizedStatus = String(status || "")
      .trim()
      .toLowerCase();
    if (normalizedStatus !== "donated" && normalizedStatus !== "restricted") {
      throw new HttpsError(
        "invalid-argument",
        'status must be "donated" or "restricted"',
      );
    }

    if (
      normalizedStatus === "restricted" &&
      (!restrictionReason || restrictionReason.trim() === "")
    ) {
      throw new HttpsError(
        "invalid-argument",
        "restrictionReason is required when status is restricted",
      );
    }

    const fileTrim =
      typeof reportFileUrl === "string" ? reportFileUrl.trim() : "";
    if (!fileTrim) {
      throw new HttpsError(
        "invalid-argument",
        "reportFileUrl is required — upload the medical report before saving.",
      );
    }

    const confirmedNorm = normalizeStandardBloodType(confirmedBloodType);
    if (!confirmedNorm) {
      throw new HttpsError(
        "invalid-argument",
        "confirmedBloodType is required and must be one of: A+, A-, B+, B-, AB+, AB-, O+, O-.",
      );
    }

    let canDonateAgainDate = null;
    if (canDonateAgainAt) {
      canDonateAgainDate = new Date(canDonateAgainAt);
      if (isNaN(canDonateAgainDate.getTime())) {
        throw new HttpsError(
          "invalid-argument",
          "canDonateAgainAt must be a valid ISO date string",
        );
      }
    }

    const req = await getRequest(requestId);

    if (req.bloodBankId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "You can only manage donors for your own requests",
      );
    }

    const donorResponseRef = db
      .collection("requests")
      .doc(requestId)
      .collection("donorResponses")
      .doc(donorId);

    const donorResponseSnap = await donorResponseRef.get();
    if (!donorResponseSnap.exists) {
      throw new HttpsError("not-found", "Donor has not accepted this request");
    }

    const donorResponseData = donorResponseSnap.data() || {};
    const donorUserSnap = await db.collection("users").doc(donorId).get();
    const donorUserData = donorUserSnap.exists
      ? donorUserSnap.data() || {}
      : {};
    const genderRaw = String(donorUserData.gender || "")
      .trim()
      .toLowerCase();
    // WHO-style whole-blood spacing: 120 days for women, 90 for men.
    const donationCooldownDays = genderRaw === "female" ? 120 : 90;

    let postDonationEligibleDate = null;
    if (normalizedStatus === "donated") {
      postDonationEligibleDate = new Date();
      postDonationEligibleDate.setUTCDate(
        postDonationEligibleDate.getUTCDate() + donationCooldownDays,
      );
    }

    const apt = donorResponseData.appointmentAt;
    const appointmentAtForReport =
      apt && typeof apt.toMillis === "function" ? apt : null;

    const reportCanDonateTs =
      normalizedStatus === "donated" && postDonationEligibleDate
        ? admin.firestore.Timestamp.fromDate(postDonationEligibleDate)
        : canDonateAgainDate
          ? admin.firestore.Timestamp.fromDate(canDonateAgainDate)
          : null;

    const isPermanentBlockBool =
      normalizedStatus === "restricted" && isPermanentBlock === true;

    const reportData = {
      requestId,
      donorId,
      bloodBankId: callerUid,
      bloodBankName: req.bloodBankName || "",
      bloodType: confirmedNorm,
      confirmedBloodType: confirmedNorm,
      isUrgent: !!req.isUrgent,
      status: normalizedStatus,
      isPermanentBlock: isPermanentBlockBool,
      restrictionReason:
        normalizedStatus === "restricted" ? restrictionReason.trim() : null,
      notes: notes && String(notes).trim() ? String(notes).trim() : null,
      reportFileUrl: fileTrim,
      canDonateAgainAt: reportCanDonateTs,
      appointmentAt: appointmentAtForReport,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const reportRef = db.collection("medicalReports").doc();
    const batch = db.batch();

    batch.set(reportRef, reportData);

    batch.update(donorResponseRef, {
      processStatus: normalizedStatus,
      appointmentStatus: "completed",
      reportId: reportRef.id,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const donorRef = db.collection("users").doc(donorId);
    const requestRef = db.collection("requests").doc(requestId);
    const schedRef = scheduleRef(db, donorId);

    const scheduleUpdate = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (normalizedStatus === "restricted") {
      if (isPermanentBlockBool) {
        // Permanent block — no expiry date, flag on schedule doc
        scheduleUpdate.isPermanentlyBlocked = true;
        scheduleUpdate.restrictionReason = restrictionReason
          ? restrictionReason.trim()
          : "";
        scheduleUpdate.restrictedUntil = admin.firestore.FieldValue.delete();
      } else if (canDonateAgainDate) {
        scheduleUpdate.restrictedUntil =
          admin.firestore.Timestamp.fromDate(canDonateAgainDate);
        scheduleUpdate.restrictionReason = restrictionReason
          ? restrictionReason.trim()
          : "";
        scheduleUpdate.isPermanentlyBlocked =
          admin.firestore.FieldValue.delete();
      }
    }

    if (normalizedStatus === "donated" && postDonationEligibleDate) {
      const nextElig = admin.firestore.Timestamp.fromDate(
        postDonationEligibleDate,
      );
      scheduleUpdate.restrictedUntil = admin.firestore.FieldValue.delete();
      scheduleUpdate.restrictionReason = admin.firestore.FieldValue.delete();
      scheduleUpdate.lastDonatedAt =
        admin.firestore.FieldValue.serverTimestamp();
      scheduleUpdate.nextDonationEligibleAt = nextElig;
      batch.update(requestRef, {
        isCompleted: true,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    batch.set(schedRef, scheduleUpdate, { merge: true });

    const userUpdate = {
      bloodType: confirmedNorm,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastDonatedAt: admin.firestore.FieldValue.delete(),
      nextDonationEligibleAt: admin.firestore.FieldValue.delete(),
      restrictedUntil: admin.firestore.FieldValue.delete(),
      restrictionReason: admin.firestore.FieldValue.delete(),
      isPermanentlyBlocked: isPermanentBlockBool
        ? true
        : admin.firestore.FieldValue.delete(),
    };

    if (donorUserSnap.exists) {
      batch.update(donorRef, userUpdate);
    } else {
      batch.set(donorRef, userUpdate, { merge: true });
    }

    await batch.commit();

    let generatedRequestId = null;
    if (normalizedStatus === "donated") {
      try {
        const autoPost = await createAndBroadcastFollowUpRequest({
          bloodBankId: callerUid,
          bloodBankName: req.bloodBankName || "",
          bloodType: confirmedNorm,
          units: 1,
          isUrgent: !!req.isUrgent,
          hospitalLocation: req.hospitalLocation || "",
          hospitalLatitude:
            typeof req.hospitalLatitude === "number"
              ? req.hospitalLatitude
              : null,
          hospitalLongitude:
            typeof req.hospitalLongitude === "number"
              ? req.hospitalLongitude
              : null,
          details:
            "Auto-generated after confirmed donation and medical report upload.",
          sourceRequestId: requestId,
          sourceReportId: reportRef.id,
        });
        generatedRequestId = autoPost.requestId || null;
      } catch (autoPostErr) {
        console.error(
          "[saveMedicalReport] Failed to generate follow-up request:",
          autoPostErr,
        );
      }
    }

    try {
      const donorSnap = await db.collection("users").doc(donorId).get();
      if (donorSnap.exists) {
        const du = donorSnap.data() || {};
        const fcmToken = du.fcmToken;

        const title =
          normalizedStatus === "donated"
            ? "🩸 Donation Confirmed!"
            : "⚠️ Donation Result";

        const body =
          normalizedStatus === "donated"
            ? `${req.bloodBankName || "The blood bank"} confirmed your ${confirmedNorm} donation. Your report is now available.`
            : `${req.bloodBankName || "The blood bank"} uploaded your donation report. Check your profile.`;

        // ✅ احفظ الإشعار داخل التطبيق
        const notifRef = db
          .collection("notifications")
          .doc(donorId)
          .collection("user_notifications")
          .doc();

        await notifRef.set({
          title,
          body,
          type: "medical_report_saved",
          requestId: String(requestId),
          reportId: String(reportRef.id),
          status: String(normalizedStatus),
          isRead: false,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // ✅ ابعث push notification
        if (typeof fcmToken === "string" && fcmToken.trim()) {
          await admin.messaging().send({
            token: fcmToken.trim(),
            notification: { title, body },
            data: {
              type: "medical_report_saved",
              requestId: String(requestId),
              reportId: String(reportRef.id),
              status: String(normalizedStatus),
            },
          });
        }
      }
    } catch (e) {
      console.warn(
        "Notification or FCM failed (saveMedicalReport):",
        e.message || e,
      );
    }

    return {
      success: true,
      reportId: reportRef.id,
      generatedRequestId,
    };
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

    const reportsSnapshot = await db
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

    const reports = reportsSnapshot.docs.map((doc) => {
      const d = doc.data() || {};
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
        appointmentAt: toISO(d.appointmentAt),
        createdAt: toISO(d.createdAt),
      };
    });

    const reportRequestIds = new Set(
      reports.map((r) => r.requestId).filter((v) => typeof v === "string" && v),
    );

    const userSnap = await db.collection("users").doc(callerUid).get();
    const uData = userSnap.exists ? userSnap.data() || {} : {};
    const trackedRaw = uData.donorAcceptedRequestIds;
    const trackedIds = Array.isArray(trackedRaw)
      ? [...new Set(trackedRaw.map(String).filter(Boolean))].slice(0, 300)
      : [];

    let donorResponseDocs = [];

    if (trackedIds.length > 0) {
      for (let i = 0; i < trackedIds.length; i += 10) {
        const chunk = trackedIds.slice(i, i + 10);
        const refs = chunk.map((rid) =>
          db
            .collection("requests")
            .doc(rid)
            .collection("donorResponses")
            .doc(callerUid),
        );
        const snaps = await db.getAll(...refs);
        for (const s of snaps) {
          if (s.exists) donorResponseDocs.push(s);
        }
      }
    } else {
      try {
        const donorResponseSnapshot = await db
          .collectionGroup("donorResponses")
          .where(admin.firestore.FieldPath.documentId(), "==", callerUid)
          .get();
        donorResponseDocs = donorResponseSnapshot.docs;
      } catch (cgErr) {
        console.warn(
          "[getDonationHistory] collectionGroup donorResponses failed:",
          cgErr.message || cgErr,
        );
      }
    }

    for (const doc of donorResponseDocs) {
      const d = doc.data() || {};
      const inviteStatus = String(d.status || "").toLowerCase();
      if (inviteStatus !== "accepted") continue;

      const requestRef = doc.ref.parent.parent;
      if (!requestRef) continue;

      const requestId = requestRef.id;
      if (reportRequestIds.has(requestId)) continue;

      const processStatus = String(d.processStatus || "accepted").toLowerCase();
      if (!["accepted", "scheduled", "tested"].includes(processStatus)) {
        continue;
      }

      const reqSnap = await requestRef.get();
      if (!reqSnap.exists) continue;
      const req = reqSnap.data() || {};

      reports.push({
        id: `active_${requestId}_${callerUid}`,
        requestId,
        bloodBankId: req.bloodBankId || "",
        bloodBankName: req.bloodBankName || "",
        bloodType: req.bloodType || "",
        isUrgent: req.isUrgent || false,
        status: processStatus,
        restrictionReason: null,
        notes: null,
        reportFileUrl: null,
        canDonateAgainAt: null,
        appointmentAt: toISO(d.appointmentAt),
        createdAt:
          toISO(d.updatedAt) ||
          toISO(req.createdAt) ||
          new Date().toISOString(),
      });
    }

    reports.sort((a, b) => {
      const at = Date.parse(a.createdAt || 0);
      const bt = Date.parse(b.createdAt || 0);
      return bt - at;
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

      if (!requestId || typeof requestId !== "string") {
        throw new HttpsError("invalid-argument", "requestId is required");
      }

      const req = await getRequest(requestId);

      if (req.bloodBankId !== callerUid) {
        throw new HttpsError(
          "permission-denied",
          "You can only view donors for your own requests",
        );
      }

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

        let fullName = d.fullName || "";
        let email = d.email || "";
        let phoneNumber =
          typeof d.phoneNumber === "string" && d.phoneNumber.trim()
            ? d.phoneNumber.trim()
            : "";

        if (!fullName || !email || !phoneNumber) {
          try {
            const donorSnap = await db.collection("users").doc(doc.id).get();
            if (donorSnap.exists) {
              const du = donorSnap.data() || {};
              fullName = fullName || du.fullName || du.name || "Donor";
              email = email || du.email || "";
              const p = du.phoneNumber;
              if (!phoneNumber && typeof p === "string" && p.trim()) {
                phoneNumber = p.trim();
              }
            }
          } catch (e) {
            console.warn("Failed to load donor user data:", e.message);
          }
        }
        const entry = {
          donorId: doc.id,
          fullName: fullName || "Donor",
          email,
          phoneNumber,
          processStatus: d.processStatus || "accepted",
          appointmentAtMillis: toMillis(d.appointmentAt),
          reportId: d.reportId || null,
        };

        if (status === "accepted") {
          accepted.push(entry);
        } else if (status === "rejected") {
          rejected.push(entry);
        }
      }

      return { accepted, rejected };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("[getRequestDonorResponses] unhandled:", e);
      throw new HttpsError("internal", "Failed to fetch donor responses.");
    }
  },
);

// ---------------------------------------------------------------------------
// 5. listBloodBankPastDonors (hospital — donors with status donated here)
// ---------------------------------------------------------------------------
exports.listBloodBankPastDonors = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const callerUid = requireAuth(request);
      await requireRole(callerUid, "hospital");

      const snap = await db
        .collection("medicalReports")
        .where("bloodBankId", "==", callerUid)
        .limit(500)
        .get();

      /** @param {FirebaseFirestore.DocumentData} d */
      function reportRequestId(d) {
        const a = d.requestId;
        const b = d.requestID;
        const raw = a != null && String(a).trim() ? a : b;
        if (raw == null) return "";
        const s = String(raw).trim();
        return s || "";
      }

      /** donorId -> { rows: { ms, rid }[] } */
      const byDonor = new Map();
      const allRequestIds = new Set();
      for (const doc of snap.docs) {
        const d = doc.data() || {};
        if (String(d.status || "").toLowerCase() !== "donated") continue;
        const donorId = d.donorId;
        if (!donorId || typeof donorId !== "string") continue;
        const ts = d.createdAt;
        let ms = 0;
        if (ts && typeof ts.toMillis === "function") ms = ts.toMillis();
        else if (ts instanceof Date) ms = ts.getTime();
        const rid = reportRequestId(d);
        if (rid) allRequestIds.add(rid);
        const cur = byDonor.get(donorId) || { rows: [] };
        cur.rows.push({ ms, rid });
        byDonor.set(donorId, cur);
      }

      const existingRequestIds = new Set();
      const reqIdList = [...allRequestIds];
      for (let i = 0; i < reqIdList.length; i += 10) {
        const chunk = reqIdList.slice(i, i + 10);
        const reqSnaps = await db.getAll(
          ...chunk.map((id) => db.collection("requests").doc(id)),
        );
        for (const rs of reqSnaps) {
          if (rs.exists) existingRequestIds.add(rs.id);
        }
      }

      const donorIds = [...byDonor.keys()];
      const donors = [];
      for (let i = 0; i < donorIds.length; i += 10) {
        const chunk = donorIds.slice(i, i + 10);
        const snaps = await db.getAll(
          ...chunk.map((id) => db.collection("users").doc(id)),
        );
        for (let j = 0; j < chunk.length; j++) {
          const donorId = chunk[j];
          const u = snaps[j];
          const ud = u.exists ? u.data() || {} : {};
          let phoneNumber = "";
          const p = ud.phoneNumber;
          if (typeof p === "string" && p.trim()) phoneNumber = p.trim();
          const bloodTypeRaw = ud.bloodType;
          const bloodType =
            typeof bloodTypeRaw === "string" && bloodTypeRaw.trim()
              ? bloodTypeRaw.trim()
              : "";
          const agg = byDonor.get(donorId);
          const rows = (agg.rows || []).slice();
          rows.sort((a, b) => b.ms - a.ms);
          let lastMs = 0;
          for (const r of rows) lastMs = Math.max(lastMs, r.ms);
          let messageRequestId = null;
          for (const r of rows) {
            if (r.rid && existingRequestIds.has(r.rid)) {
              messageRequestId = r.rid;
              break;
            }
          }
          donors.push({
            donorId,
            fullName: ud.fullName || ud.name || "Donor",
            email: typeof ud.email === "string" ? ud.email : "",
            phoneNumber,
            bloodType,
            donationCount: rows.length,
            lastDonatedAtMs: lastMs || null,
            messageRequestId,
          });
        }
      }

      donors.sort(
        (a, b) => (b.lastDonatedAtMs || 0) - (a.lastDonatedAtMs || 0),
      );
      return { ok: true, donors };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("[listBloodBankPastDonors] unhandled:", e);
      throw new HttpsError("internal", "Failed to list past donors.");
    }
  },
);

// ---------------------------------------------------------------------------
// 6. getBloodBankDonorMedicalHistory (hospital — reports at this bank)
// ---------------------------------------------------------------------------
exports.getBloodBankDonorMedicalHistory = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const callerUid = requireAuth(request);
      await requireRole(callerUid, "hospital");
      const donorId = (request.data || {}).donorId;
      if (!donorId || typeof donorId !== "string") {
        throw new HttpsError("invalid-argument", "donorId is required");
      }

      const snap = await db
        .collection("medicalReports")
        .where("bloodBankId", "==", callerUid)
        .limit(500)
        .get();

      const rows = snap.docs
        .filter((doc) => (doc.data() || {}).donorId === donorId)
        .map(serializeMedicalReportDoc)
        .sort((a, b) => {
          const at = Date.parse(a.createdAt || 0) || 0;
          const bt = Date.parse(b.createdAt || 0) || 0;
          return bt - at;
        })
        .slice(0, 100);

      return { reports: rows };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("[getBloodBankDonorMedicalHistory] unhandled:", e);
      throw new HttpsError(
        "internal",
        "Failed to fetch donor medical history.",
      );
    }
  },
);

// ---------------------------------------------------------------------------
// 7. cleanupMissedScheduledAppointments (daily)
// ---------------------------------------------------------------------------
// If donor stayed in "scheduled" for more than 7 days past appointment time,
// remove from the scheduled list by moving processStatus back to "accepted".
exports.cleanupMissedScheduledAppointments = onSchedule(
  {
    schedule: "0 */6 * * *", // every 6 hours
    timeZone: "Asia/Amman",
    region: "us-central1",
  },
  async () => {
    const cutoffMs = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const cutoffTs = admin.firestore.Timestamp.fromMillis(cutoffMs);

    try {
      const requestsSnap = await db.collection("requests").get();
      let checked = 0;
      let markedMissed = 0;

      for (const reqDoc of requestsSnap.docs) {
        const scheduledSnap = await reqDoc.ref
          .collection("donorResponses")
          .where("processStatus", "==", "scheduled")
          .get();

        if (scheduledSnap.empty) continue;

        let batch = db.batch();
        let inBatch = 0;

        for (const donorDoc of scheduledSnap.docs) {
          checked += 1;
          const row = donorDoc.data() || {};
          const apt = row.appointmentAt;
          if (!apt || typeof apt.toMillis !== "function") continue;
          if (apt.toMillis() > cutoffMs) continue;

          batch.update(donorDoc.ref, {
            processStatus: "accepted",
            appointmentStatus: "missed",
            appointmentAt: admin.firestore.FieldValue.delete(),
            scheduledAt: admin.firestore.FieldValue.delete(),
            scheduledBy: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            missedAt: admin.firestore.FieldValue.serverTimestamp(),
            missedAfterCutoff: cutoffTs,
          });
          inBatch += 1;
          markedMissed += 1;

          if (inBatch >= 400) {
            await batch.commit();
            batch = db.batch();
            inBatch = 0;
          }
        }

        if (inBatch > 0) {
          await batch.commit();
        }
      }

      console.log(
        `[cleanupMissedScheduledAppointments] checked=${checked}, markedMissed=${markedMissed}`,
      );
      return null;
    } catch (e) {
      console.error("[cleanupMissedScheduledAppointments] ERROR:", e);
      return null;
    }
  },
);
