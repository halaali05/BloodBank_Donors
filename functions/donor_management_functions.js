const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

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
  const userData = userSnap.data();
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
  return { id: reqSnap.id, ...reqSnap.data() };
}

// ---------------------------------------------------------------------------
// 1. scheduleDonorAppointment
// ---------------------------------------------------------------------------
exports.scheduleDonorAppointment = onCall(async (request) => {
  const callerUid = requireAuth(request);
  await requireRole(callerUid, "hospital");

  const { requestId, donorId, appointmentAt } = request.data;

  if (!requestId || typeof requestId !== "string")
    throw new HttpsError("invalid-argument", "requestId is required");
  if (!donorId || typeof donorId !== "string")
    throw new HttpsError("invalid-argument", "donorId is required");
  if (!appointmentAt || typeof appointmentAt !== "string")
    throw new HttpsError("invalid-argument", "appointmentAt is required");

  const appointmentDate = new Date(appointmentAt);
  if (isNaN(appointmentDate.getTime()))
    throw new HttpsError(
      "invalid-argument",
      "appointmentAt must be a valid ISO date string",
    );
  if (appointmentDate < new Date())
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

  // ✅ donorResponses بدل acceptances
  const donorResponseRef = db
    .collection("requests")
    .doc(requestId)
    .collection("donorResponses")
    .doc(donorId);

  const donorResponseSnap = await donorResponseRef.get();
  if (!donorResponseSnap.exists)
    throw new HttpsError("not-found", "Donor has not accepted this request");

  const currentStatus =
    donorResponseSnap.data().processStatus ||
    donorResponseSnap.data().status ||
    "accepted";
  if (currentStatus !== "accepted")
    throw new HttpsError(
      "failed-precondition",
      `Donor is already in status: ${currentStatus}`,
    );

  await donorResponseRef.update({
    processStatus: "scheduled",
    appointmentAt: admin.firestore.Timestamp.fromDate(appointmentDate),
    scheduledAt: admin.firestore.FieldValue.serverTimestamp(),
    scheduledBy: callerUid,
  });

  // FCM — non-critical
  try {
    const donorSnap = await db.collection("users").doc(donorId).get();
    if (donorSnap.exists) {
      const fcmToken = donorSnap.data().fcmToken;
      if (fcmToken) {
        const dateStr = appointmentDate.toLocaleDateString("en-US", {
          weekday: "short",
          month: "short",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        });
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "📅 Appointment Scheduled",
            body: `${req.bloodBankName || "The blood bank"} scheduled your ${req.bloodType || ""} donation for ${dateStr}`,
          },
          data: { type: "appointment_scheduled", requestId, appointmentAt },
        });
      }
    }
  } catch (e) {
    console.warn("FCM failed (scheduleDonorAppointment):", e.message);
  }

  return { success: true, message: "Appointment scheduled" };
});

// ---------------------------------------------------------------------------
// 2. saveMedicalReport
// ---------------------------------------------------------------------------
exports.saveMedicalReport = onCall(async (request) => {
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

  // ✅ donorResponses بدل acceptances
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

  // ✅ تحديث donorResponses
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

  // FCM — non-critical
  try {
    const donorSnap = await db.collection("users").doc(donorId).get();
    if (donorSnap.exists) {
      const fcmToken = donorSnap.data().fcmToken;
      if (fcmToken) {
        const title =
          status === "donated"
            ? "🩸 Donation Confirmed!"
            : "⚠️ Donation Result";
        const body =
          status === "donated"
            ? `${req.bloodBankName || "The blood bank"} confirmed your ${req.bloodType || ""} donation. Thank you!`
            : `${req.bloodBankName || "The blood bank"} has a note regarding your ${req.bloodType || ""} donation. Check your profile.`;
        await admin.messaging().send({
          token: fcmToken,
          notification: { title, body },
          data: {
            type: "medical_report_saved",
            requestId,
            reportId: reportRef.id,
            status,
          },
        });
      }
    }
  } catch (e) {
    console.warn("FCM failed (saveMedicalReport):", e.message);
  }

  return { success: true, reportId: reportRef.id };
});

// ---------------------------------------------------------------------------
// 3. getDonationHistory
// ---------------------------------------------------------------------------
exports.getDonationHistory = onCall(async (request) => {
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
      bloodBankName: d.bloodBankName || "",
      bloodType: d.bloodType || "",
      status: d.status || "donated",
      restrictionReason: d.restrictionReason || null,
      notes: d.notes || null,
      reportFileUrl: d.reportFileUrl || null,
      canDonateAgainAt: toISO(d.canDonateAgainAt),
      createdAt: toISO(d.createdAt),
    };
  });

  return { reports };
});
