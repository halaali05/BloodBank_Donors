const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { requireAuth, nonEmptyString, toHttpsError } = require("./utils");
const { publicCallableOpts } = require("../callable_config");
const {
  scheduleRef,
  mergeUserWithScheduleSnap,
} = require("../donation_schedule");

const db = admin.firestore();

const REQUEST_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Callables / JSON may send "true", 1, etc. Urgent FCM + Firestore must stay aligned.
 */
function coerceUrgent(value) {
  if (value === true) return true;
  if (value === false || value == null) return false;
  if (typeof value === "string") {
    const s = value.trim().toLowerCase();
    return s === "true" || s === "1" || s === "yes";
  }
  if (typeof value === "number") return value === 1;
  return false;
}

function isRequestExpired(createdAtValue) {
  if (!createdAtValue || typeof createdAtValue.toMillis !== "function") {
    return false;
  }
  return Date.now() - createdAtValue.toMillis() > REQUEST_TTL_MS;
}

/** Parse Firestore Timestamp / Date / epoch ms from user document fields. */
function millisFromFirestoreValue(v) {
  if (v == null) return null;
  if (typeof v.toMillis === "function") return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (
    typeof v === "object" &&
    typeof v._seconds === "number" &&
    Number.isFinite(v._seconds)
  ) {
    return v._seconds * 1000 + Math.floor((v._nanoseconds || 0) / 1e6);
  }
  return null;
}

function appointmentMillis(appt) {
  if (!appt) return null;
  if (typeof appt.toMillis === "function") return appt.toMillis();
  if (appt._seconds) return appt._seconds * 1000;
  if (typeof appt === "number") return appt;
  if (typeof appt === "string") {
    const parsed = Date.parse(appt);
    return isNaN(parsed) ? null : parsed;
  }
  return null;
}

/**
 * Best-effort phone string from a Firestore map (users/* or donorResponses/*).
 * Handles numeric storage and alternate field names.
 */
function pickPhoneFromObject(o) {
  if (!o || typeof o !== "object") return "";
  const keys = [
    "phoneNumber",
    "phone",
    "mobile",
    "phoneNo",
    "msisdn",
    "cellPhone",
  ];
  for (const k of keys) {
    const c = o[k];
    if (c == null) continue;
    let s;
    if (typeof c === "string") {
      s = c.trim();
    } else if (typeof c === "number" && Number.isFinite(c)) {
      s = String(c).trim();
    } else {
      s = String(c).trim();
    }
    if (s && s !== "undefined" && s !== "null") return s;
  }
  return "";
}

/**
 * End of post-donation "I can donate" cooldown (epoch ms), or null.
 * Uses max(nextDonationEligibleAt, lastDonatedAt + 90/120d) so older profiles
 * without nextDonationEligibleAt are still enforced.
 */
function donorDonationCooldownEndMs(userData) {
  if (!userData || typeof userData !== "object") return null;
  const explicit = millisFromFirestoreValue(userData.nextDonationEligibleAt);
  const lastDon = millisFromFirestoreValue(userData.lastDonatedAt);
  const genderRaw = String(userData.gender || "")
    .trim()
    .toLowerCase();
  const days = genderRaw === "female" ? 120 : 90;
  let fromLast = null;
  if (lastDon != null) {
    fromLast = lastDon + days * 86400000;
  }
  const parts = [explicit, fromLast].filter(
    (x) => x != null && Number.isFinite(x),
  );
  if (parts.length === 0) return null;
  return Math.max(...parts);
}

function assertDonorMayAcceptNewRequest(userData) {
  const now = Date.now();

  if (userData.isPermanentlyBlocked === true) {
    throw new HttpsError(
      "failed-precondition",
      "You are permanently blocked from donating due to medical reasons.",
    );
  }

  const coolEnd = donorDonationCooldownEndMs(userData);
  if (coolEnd != null && now < coolEnd) {
    throw new HttpsError(
      "failed-precondition",
      "Now, you're not eligible to donate. Open When can I donate? for more details.",
    );
  }
  const restr = millisFromFirestoreValue(userData.restrictedUntil);
  if (restr != null && now < restr) {
    throw new HttpsError(
      "failed-precondition",
      "You are medically restricted from donating until the restriction date.",
    );
  }
}

async function deleteRequestCascade(requestRef, requestId) {
  let notificationsDeleted = 0;

  const trimmedRequestId = String(requestId ?? "").trim();
  const responsesSnapshot = await requestRef.collection("donorResponses").get();

  const requestIdVariants = [trimmedRequestId];
  const asNumber = Number(trimmedRequestId);
  if (
    trimmedRequestId !== "" &&
    !Number.isNaN(asNumber) &&
    Number.isFinite(asNumber)
  ) {
    requestIdVariants.push(asNumber);
  }

  const uniqueNotificationRefs = new Map();
  function collectSnapshot(snap) {
    for (const doc of snap.docs) {
      uniqueNotificationRefs.set(doc.ref.path, doc.ref);
    }
  }

  // Collection-group queries: if ANY query fails (e.g. missing index on one
  // field), Promise.all would skip ALL deletes. Use allSettled instead.
  const cgQueries = [];
  for (const idValue of requestIdVariants) {
    cgQueries.push(
      db
        .collectionGroup("user_notifications")
        .where("requestId", "==", idValue),
    );
    cgQueries.push(
      db
        .collectionGroup("user_notifications")
        .where("requestID", "==", idValue),
    );
  }

  const cgSettled = await Promise.allSettled(cgQueries.map((q) => q.get()));
  cgSettled.forEach((r, i) => {
    if (r.status === "fulfilled") {
      collectSnapshot(r.value);
    } else {
      console.warn(
        `[deleteRequestCascade] collectionGroup query ${i} failed: ${
          r.reason && r.reason.message ? r.reason.message : r.reason
        }`,
      );
    }
  });

  // Also delete via each donor who responded — uses only single-field
  // subcollection queries (reliable even when a collectionGroup index fails).
  const perDonorGets = [];
  for (const d of responsesSnapshot.docs) {
    const coll = db
      .collection("notifications")
      .doc(d.id)
      .collection("user_notifications");
    for (const idValue of requestIdVariants) {
      perDonorGets.push(coll.where("requestId", "==", idValue).get());
      perDonorGets.push(coll.where("requestID", "==", idValue).get());
    }
  }

  const CHUNK = 80;
  for (let i = 0; i < perDonorGets.length; i += CHUNK) {
    const slice = perDonorGets.slice(i, i + CHUNK);
    const settled = await Promise.allSettled(slice);
    settled.forEach((r, j) => {
      if (r.status === "fulfilled") {
        collectSnapshot(r.value);
      } else {
        console.warn(
          `[deleteRequestCascade] per-donor notification query failed: ${
            r.reason && r.reason.message ? r.reason.message : r.reason
          } (chunk ${i}+${j})`,
        );
      }
    });
  }

  const refsToDelete = [...uniqueNotificationRefs.values()];
  if (refsToDelete.length > 0) {
    const batchSize = 500;
    for (let i = 0; i < refsToDelete.length; i += batchSize) {
      const batch = db.batch();
      refsToDelete.slice(i, i + batchSize).forEach((ref) => {
        batch.delete(ref);
        notificationsDeleted++;
      });
      await batch.commit();
    }
  }

  if (!responsesSnapshot.empty) {
    const batchSize = 500;
    const respDeletePromises = [];
    for (let i = 0; i < responsesSnapshot.docs.length; i += batchSize) {
      const batch = db.batch();
      responsesSnapshot.docs.slice(i, i + batchSize).forEach((doc) => {
        batch.delete(doc.ref);
      });
      respDeletePromises.push(batch.commit());
    }
    if (respDeletePromises.length > 0) {
      await Promise.all(respDeletePromises);
    }
  }

  const messagesSnapshot = await requestRef.collection("messages").get();
  if (!messagesSnapshot.empty) {
    const batchSize = 500;
    const messageDeletePromises = [];
    for (let i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
      const batch = db.batch();
      messagesSnapshot.docs.slice(i, i + batchSize).forEach((doc) => {
        batch.delete(doc.ref);
      });
      messageDeletePromises.push(batch.commit());
    }
    if (messageDeletePromises.length > 0) {
      await Promise.all(messageDeletePromises);
    }
  }

  await requestRef.delete();
  return { notificationsDeleted };
}

function serializeMedicalReportForClient(doc) {
  const d = doc.data() || {};
  const toISO = (ts) => {
    if (!ts) return null;
    if (typeof ts.toDate === "function") return ts.toDate().toISOString();
    if (ts instanceof Date) return ts.toISOString();
    if (typeof ts === "string") return ts;
    return null;
  };
  return {
    id: doc.id,
    requestId: d.requestId || "",
    bloodBankId: d.bloodBankId || "",
    bloodBankName: d.bloodBankName || "",
    bloodType: d.bloodType || d.confirmedBloodType || "",
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

async function getLatestUploadedMedicalReportsByDonor(donorIds) {
  const uniqueDonorIds = [...new Set(donorIds.filter(Boolean))];
  const latestByDonor = new Map();
  if (uniqueDonorIds.length === 0) return latestByDonor;

  for (let i = 0; i < uniqueDonorIds.length; i += 30) {
    const chunk = uniqueDonorIds.slice(i, i + 30);
    const snap = await db
      .collection("medicalReports")
      .where("donorId", "in", chunk)
      .limit(chunk.length * 50)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const url = data.reportFileUrl;
      const donorId = data.donorId;
      if (
        typeof donorId !== "string" ||
        !donorId ||
        typeof url !== "string" ||
        !url.trim()
      ) {
        continue;
      }

      const createdAt = data.createdAt;
      let createdAtMs = 0;
      if (createdAt && typeof createdAt.toMillis === "function") {
        createdAtMs = createdAt.toMillis();
      } else if (createdAt instanceof Date) {
        createdAtMs = createdAt.getTime();
      } else if (typeof createdAt === "string") {
        createdAtMs = Date.parse(createdAt) || 0;
      }

      const current = latestByDonor.get(donorId);
      if (!current || createdAtMs > current.createdAtMs) {
        latestByDonor.set(donorId, {
          createdAtMs,
          report: serializeMedicalReportForClient(doc),
        });
      }
    }
  }

  return new Map(
    [...latestByDonor.entries()].map(([donorId, value]) => [
      donorId,
      value.report,
    ]),
  );
}

function millisFromPipelineValue(ts) {
  if (!ts) return null;
  if (typeof ts.toMillis === "function") return ts.toMillis();
  if (ts instanceof Date) return ts.getTime();
  if (typeof ts === "number" && Number.isFinite(ts)) return ts;
  if (typeof ts === "string") {
    const s = ts.trim();
    if (!s) return null;
    if (/^\d+$/.test(s)) {
      const n = Number(s);
      return Number.isFinite(n) ? n : null;
    }
    const p = Date.parse(s);
    return isNaN(p) ? null : p;
  }
  if (
    typeof ts === "object" &&
    typeof ts._seconds === "number" &&
    Number.isFinite(ts._seconds)
  ) {
    return ts._seconds * 1000 + Math.floor((ts._nanoseconds || 0) / 1e6);
  }
  return null;
}

async function buildDonorManagementEntries(responseDocs, options = {}) {
  const includeLatestReports = options.includeLatestReports !== false;
  const userRefs = responseDocs.map((doc) =>
    db.collection("users").doc(doc.id),
  );
  const userSnaps = userRefs.length > 0 ? await db.getAll(...userRefs) : [];
  const reportsByDonor = includeLatestReports
    ? await getLatestUploadedMedicalReportsByDonor(
        responseDocs.map((doc) => doc.id),
      )
    : new Map();

  return responseDocs.map((doc, index) => {
    const row = doc.data() || {};
    const userSnap = userSnaps[index];
    const userData = userSnap && userSnap.exists ? userSnap.data() || {} : {};
    const rowPhone = pickPhoneFromObject(row);
    const userPhone = pickPhoneFromObject(userData);
    const fullName =
      (typeof row.fullName === "string" && row.fullName.trim()) ||
      (typeof userData.fullName === "string" && userData.fullName.trim()) ||
      (typeof userData.name === "string" && userData.name.trim()) ||
      "Donor";
    const email =
      (typeof row.email === "string" && row.email.trim()) ||
      (typeof userData.email === "string" && userData.email.trim()) ||
      "";
    const bloodType =
      (typeof userData.bloodType === "string" && userData.bloodType.trim()) ||
      (typeof row.bloodType === "string" && row.bloodType.trim()) ||
      null;
    const rescheduleReason =
      typeof row.rescheduleReason === "string" && row.rescheduleReason.trim()
        ? row.rescheduleReason.trim()
        : null;

    return {
      donorId: doc.id,
      fullName,
      email,
      phoneNumber: userPhone || rowPhone || "",
      bloodType,
      processStatus: row.processStatus ?? null,
      appointmentStatus:
        typeof row.appointmentStatus === "string" &&
        row.appointmentStatus.trim()
          ? row.appointmentStatus.trim().toLowerCase()
          : null,
      appointmentAtMillis: millisFromPipelineValue(row.appointmentAt),
      rescheduleReason,
      reschedulePreferredAtMillis: millisFromPipelineValue(
        row.reschedulePreferredAt,
      ),
      rescheduleRequestedAtMillis: millisFromPipelineValue(
        row.rescheduleRequestedAt,
      ),
      latestMedicalReport: reportsByDonor.get(doc.id) || null,
    };
  });
}

/**
 * Haversine formula — calculates distance in km between two GPS coordinates.
 * (kept for reference but no longer used for filtering)
 */
// eslint-disable-next-line no-unused-vars -- reference only
function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * addRequest - hospitals only.
 */
exports.addRequest = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const userSnap = await db.collection("users").doc(uid).get();
    const ud = userSnap.exists ? userSnap.data() || {} : {};

    if (!userSnap.exists || ud.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can create blood requests",
      );
    }

    const requestId = nonEmptyString(data.requestId, "requestId");
    const bloodBankName = nonEmptyString(data.bloodBankName, "bloodBankName");
    const bloodType = nonEmptyString(data.bloodType, "bloodType");

    const units =
      typeof data.units === "number" ? data.units : parseInt(data.units, 10);
    if (isNaN(units) || units < 1) {
      throw new HttpsError(
        "invalid-argument",
        "units must be a positive number",
      );
    }

    const isUrgent = coerceUrgent(data.isUrgent);
    const hospitalLocation = nonEmptyString(
      data.hospitalLocation,
      "hospitalLocation",
    );
    const details = typeof data.details === "string" ? data.details.trim() : "";

    const hospitalLatitude =
      typeof data.hospitalLatitude === "number" ? data.hospitalLatitude : null;
    const hospitalLongitude =
      typeof data.hospitalLongitude === "number"
        ? data.hospitalLongitude
        : null;

    const requestPayload = {
      bloodBankId: uid,
      bloodBankName,
      bloodType,
      units,
      isUrgent,
      details,
      hospitalLocation,
      hospitalLatitude,
      hospitalLongitude,
      acceptedCount: 0,
      rejectedCount: 0,
      isCompleted: false,
      completedAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection("requests").doc(requestId).set(requestPayload);

    console.log(
      `[addRequest] Request ${requestId} created. hospitalLocation=${hospitalLocation}`,
    );

    // Notify donors in the same callable — more reliable than Firestore triggers
    // (triggers can miss events, use wrong DB, or fail silently).
    try {
      await notifyDonorsForNewRequest(requestId, {
        bloodBankId: uid,
        bloodBankName,
        bloodType,
        units,
        isUrgent,
        details,
        hospitalLocation,
        hospitalLatitude,
        hospitalLongitude,
      });
    } catch (notifyErr) {
      console.error(
        "[addRequest] notifyDonorsForNewRequest failed (request still saved):",
        notifyErr,
      );
    }

    return {
      ok: true,
      message:
        "Request created and personalized messages sent to all matching donors.",
    };
  } catch (err) {
    console.error("[addRequest] ERROR:", err);
    throw toHttpsError(err, "Failed to create request.");
  }
});

/**
 * getDonors - Get list of all donors (hospitals only).
 */
exports.getDonors = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    if (userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can view donor lists.",
      );
    }

    const bloodType =
      typeof data.bloodType === "string" && data.bloodType.trim() !== ""
        ? data.bloodType.trim()
        : null;
    const limit =
      typeof data.limit === "number" ? Math.min(data.limit, 100) : 80;

    let query = db.collection("users").where("role", "==", "donor");
    if (bloodType) {
      query = query.where("bloodType", "==", bloodType);
    }
    query = query.limit(limit);

    const donorsSnapshot = await query.get();

    const donors = donorsSnapshot.docs.map((doc) => {
      const donorData = doc.data();
      const phoneNumber = pickPhoneFromObject(donorData);
      return {
        id: doc.id,
        fullName: donorData.fullName || donorData.name || "Donor",
        location: donorData.location || "Unknown location",
        bloodType: donorData.bloodType || "",
        email: donorData.email || "",
        phoneNumber,
      };
    });

    return {
      ok: true,
      donors,
      count: donors.length,
      hasMore: donorsSnapshot.docs.length === limit,
    };
  } catch (err) {
    console.error("[getDonors] ERROR:", err);
    throw toHttpsError(err, "Failed to get donors list.");
  }
});

/**
 * getRequests - pagination (all requests for donors).
 */
exports.getRequests = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};

    const limit =
      typeof data.limit === "number" ? Math.min(data.limit, 100) : 50;

    const lastRequestId =
      typeof data.lastRequestId === "string" ? data.lastRequestId : null;

    let query = db
      .collection("requests")
      .orderBy("createdAt", "desc")
      .limit(limit);

    if (lastRequestId) {
      const lastDoc = await db.collection("requests").doc(lastRequestId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    const snapshot = await query.get();

    const responseRefs = snapshot.docs.map((doc) =>
      doc.ref.collection("donorResponses").doc(uid),
    );
    let responseSnaps = [];
    try {
      responseSnaps =
        responseRefs.length > 0 ? await db.getAll(...responseRefs) : [];
    } catch (e) {
      console.warn("[getRequests] donorResponse batch read:", e.message);
      responseSnaps = [];
    }

    const requests = snapshot.docs.map((doc, index) => {
      const d = doc.data() || {};

      if (isRequestExpired(d.createdAt)) {
        return null;
      }

      let myResponse = null;
      let appointmentAt = null;
      let processStatus = null;

      const respSnap = responseSnaps[index];
      if (respSnap && respSnap.exists) {
        const respData = respSnap.data() || {};
        const st = respData.status;

        if (st === "accepted" || st === "rejected") {
          myResponse = st;
        }

        if (typeof respData.processStatus === "string") {
          processStatus = respData.processStatus;
        }

        appointmentAt = appointmentMillis(respData.appointmentAt);
      }

      return {
        id: doc.id,
        ...d,

        acceptedCount:
          typeof d.acceptedCount === "number" ? d.acceptedCount : 0,

        rejectedCount:
          typeof d.rejectedCount === "number" ? d.rejectedCount : 0,

        myResponse,
        appointmentAt,
        processStatus,

        createdAt:
          d.createdAt && typeof d.createdAt.toMillis === "function"
            ? d.createdAt.toMillis()
            : null,
      };
    });

    return {
      requests: requests.filter((r) => r !== null),
      hasMore: snapshot.docs.length === limit,
    };
  } catch (err) {
    console.error("[getRequests] ERROR:", err);
    throw toHttpsError(err, "Failed to load requests.");
  }
});

/**
 * getRequestById - single request lookup for detail/notification screens.
 */
exports.getRequestById = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const requestId = nonEmptyString(data.requestId, "requestId");

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }
    const userData = userSnap.data() || {};
    const role = String(userData.role || "")
      .trim()
      .toLowerCase();

    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }

    const d = requestSnap.data() || {};
    if (role === "hospital" && d.bloodBankId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You can only view your own request.",
      );
    }

    let myResponse = null;
    let appointmentAt = null;
    let processStatus = null;

    if (role === "donor") {
      const respSnap = await requestRef
        .collection("donorResponses")
        .doc(uid)
        .get();
      if (respSnap.exists) {
        const respData = respSnap.data() || {};
        const st = respData.status;
        if (st === "accepted" || st === "rejected") {
          myResponse = st;
        }
        if (typeof respData.processStatus === "string") {
          processStatus = respData.processStatus;
        }
        appointmentAt = appointmentMillis(respData.appointmentAt);
      } else if (isRequestExpired(d.createdAt)) {
        throw new HttpsError("not-found", "Request not found.");
      }
    } else if (role !== "hospital") {
      throw new HttpsError("permission-denied", "Unsupported user role.");
    }

    return {
      request: {
        id: requestSnap.id,
        ...d,
        acceptedCount:
          typeof d.acceptedCount === "number" ? d.acceptedCount : 0,
        rejectedCount:
          typeof d.rejectedCount === "number" ? d.rejectedCount : 0,
        myResponse,
        appointmentAt,
        processStatus,
        createdAt:
          d.createdAt && typeof d.createdAt.toMillis === "function"
            ? d.createdAt.toMillis()
            : null,
      },
    };
  } catch (err) {
    console.error("[getRequestById] ERROR:", err);
    throw toHttpsError(err, "Failed to load request.");
  }
});

/**
 * getRequestsByBloodBankId - Get all requests for a specific blood bank.
 */
exports.getRequestsByBloodBankId = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const uid = requireAuth(request);
      const data = request.data || {};
      const limit =
        typeof data.limit === "number" ? Math.min(data.limit, 100) : 80;

      const userSnap = await db.collection("users").doc(uid).get();
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User profile not found.");
      }

      const userData = userSnap.data() || {};
      if (userData.role !== "hospital") {
        throw new HttpsError(
          "permission-denied",
          "Only hospitals can view their requests.",
        );
      }

      const snapshot = await db
        .collection("requests")
        .where("bloodBankId", "==", uid)
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get();

      const requests = await Promise.all(
        snapshot.docs.map(async (doc) => {
          const d = doc.data() || {};
          if (isRequestExpired(d.createdAt)) {
            return null;
          }
          const responsesSnap = await doc.ref
            .collection("donorResponses")
            .get();
          const acceptedDonors = [];
          const rejectedDonors = [];
          const entries = await buildDonorManagementEntries(responsesSnap.docs);
          for (let i = 0; i < responsesSnap.docs.length; i++) {
            const rdoc = responsesSnap.docs[i];
            const st = (rdoc.data() || {}).status;
            const entry = entries[i];
            if (st === "accepted") {
              acceptedDonors.push(entry);
            } else if (st === "rejected") {
              rejectedDonors.push(entry);
            }
          }
          return {
            id: doc.id,
            ...d,
            acceptedCount:
              typeof d.acceptedCount === "number" ? d.acceptedCount : 0,
            rejectedCount:
              typeof d.rejectedCount === "number" ? d.rejectedCount : 0,
            acceptedDonors,
            rejectedDonors,
            createdAt:
              d.createdAt && typeof d.createdAt.toMillis === "function"
                ? d.createdAt.toMillis()
                : null,
          };
        }),
      );

      const liveRequests = requests.filter((r) => r !== null);
      return {
        requests: liveRequests,
        count: liveRequests.length,
        hasMore: snapshot.docs.length === limit,
      };
    } catch (err) {
      console.error("[getRequestsByBloodBankId] ERROR:", err);
      throw toHttpsError(err, "Failed to load requests.");
    }
  },
);

/**
 * setDonorRequestResponse — donors set or clear "I can donate".
 * Stores per-donor choice under requests/{id}/donorResponses/{uid}
 * and maintains acceptedCount / rejectedCount on the request document.
 */
exports.setDonorRequestResponse = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const uid = requireAuth(request);
      const data = request.data || {};
      const requestId = nonEmptyString(data.requestId, "requestId");
      const responseRaw =
        typeof data.response === "string"
          ? data.response.trim().toLowerCase()
          : "";
      if (
        responseRaw !== "accepted" &&
        responseRaw !== "rejected" &&
        responseRaw !== "none"
      ) {
        throw new HttpsError(
          "invalid-argument",
          "response must be 'accepted', 'rejected', or 'none'",
        );
      }
      const newStatus = responseRaw === "none" ? null : responseRaw;

      const userSnap = await db.collection("users").doc(uid).get();
      const userData = userSnap.exists ? userSnap.data() || {} : {};
      if (!userSnap.exists || userData.role !== "donor") {
        throw new HttpsError(
          "permission-denied",
          "Only donors can respond to blood requests.",
        );
      }

      const requestRef = db.collection("requests").doc(requestId);
      const responseRef = requestRef.collection("donorResponses").doc(uid);
      const userRef = db.collection("users").doc(uid);
      const schedRef = scheduleRef(db, uid);

      await db.runTransaction(async (t) => {
        const uSnap = await t.get(userRef);
        const sSnap = await t.get(schedRef);
        const uData = mergeUserWithScheduleSnap(
          uSnap.exists ? uSnap.data() || {} : {},
          sSnap,
        );
        if (newStatus === "accepted") {
          assertDonorMayAcceptNewRequest(uData);
        }

        const reqSnap = await t.get(requestRef);
        if (!reqSnap.exists) {
          throw new HttpsError("not-found", "Request not found.");
        }
        const requestData = reqSnap.data() || {};
        if (requestData.isCompleted === true) {
          throw new HttpsError(
            "failed-precondition",
            "This request is already completed and no longer accepts responses.",
          );
        }

        const respSnap = await t.get(responseRef);
        const oldStatus = respSnap.exists
          ? (respSnap.data() || {}).status
          : null;
        if (oldStatus !== "accepted" && oldStatus !== "rejected") {
          // ignore unknown prior values
        }

        if (oldStatus === newStatus) {
          return;
        }

        const rd = reqSnap.data() || {};
        let accepted =
          typeof rd.acceptedCount === "number" ? rd.acceptedCount : 0;
        let rejected =
          typeof rd.rejectedCount === "number" ? rd.rejectedCount : 0;

        if (oldStatus === "accepted") {
          accepted = Math.max(0, accepted - 1);
        } else if (oldStatus === "rejected") {
          rejected = Math.max(0, rejected - 1);
        }

        if (newStatus === "accepted") {
          accepted += 1;
        } else if (newStatus === "rejected") {
          rejected += 1;
        }

        t.update(requestRef, {
          acceptedCount: accepted,
          rejectedCount: rejected,
        });

        if (newStatus == null) {
          t.delete(responseRef);
        } else {
          const respPayload = {
            status: newStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          if (newStatus === "accepted") {
            const fn =
              (typeof uData.fullName === "string" && uData.fullName.trim()) ||
              (typeof uData.name === "string" && uData.name.trim()) ||
              "";
            const em =
              typeof uData.email === "string" ? uData.email.trim() : "";
            const ph = pickPhoneFromObject(uData);
            const bt =
              typeof uData.bloodType === "string" && uData.bloodType.trim()
                ? uData.bloodType.trim()
                : "";
            if (fn) respPayload.fullName = fn;
            if (em) respPayload.email = em;
            if (ph) respPayload.phoneNumber = ph;
            if (bt) respPayload.bloodType = bt;
          }
          t.set(responseRef, respPayload, { merge: true });
        }

        // Keep request IDs on the donor profile so getDonationHistory can load
        // donorResponses without collection-group queries (avoids index / empty history).
        if (oldStatus === "accepted" && newStatus !== "accepted") {
          t.set(
            userRef,
            {
              donorAcceptedRequestIds:
                admin.firestore.FieldValue.arrayRemove(requestId),
            },
            { merge: true },
          );
        } else if (newStatus === "accepted" && oldStatus !== "accepted") {
          t.set(
            userRef,
            {
              donorAcceptedRequestIds:
                admin.firestore.FieldValue.arrayUnion(requestId),
            },
            { merge: true },
          );
        }
      });

      return { ok: true, status: newStatus ?? "none" };
    } catch (err) {
      console.error("[setDonorRequestResponse] ERROR:", err);
      throw toHttpsError(err, "Failed to save response.");
    }
  },
);

/**
 * markRequestCompleted - hospitals only, must own the request.
 * Marks request as completed so it is no longer actionable for donors.
 */
exports.markRequestCompleted = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const requestId = nonEmptyString(data.requestId, "requestId");

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};
    if (!userSnap.exists || userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can complete requests.",
      );
    }

    const requestRef = db.collection("requests").doc(requestId);
    await db.runTransaction(async (t) => {
      const reqSnap = await t.get(requestRef);
      if (!reqSnap.exists) {
        throw new HttpsError("not-found", "Request not found.");
      }
      const rd = reqSnap.data() || {};
      if (rd.bloodBankId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "You can only complete your own requests.",
        );
      }
      if (rd.isCompleted === true) {
        return;
      }
      t.update(requestRef, {
        isCompleted: true,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { ok: true, isCompleted: true };
  } catch (err) {
    console.error("[markRequestCompleted] ERROR:", err);
    throw toHttpsError(err, "Failed to mark request as completed.");
  }
});

/**
 * updateRequestUnits - hospitals only, must own the request.
 */
exports.updateRequestUnits = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const requestId = nonEmptyString(data.requestId, "requestId");

    const units =
      typeof data.units === "number" ? data.units : parseInt(data.units, 10);
    if (!Number.isInteger(units) || units < 1) {
      throw new HttpsError(
        "invalid-argument",
        "units must be an integer greater than 0.",
      );
    }

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};
    if (!userSnap.exists || userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can update requests.",
      );
    }

    const requestRef = db.collection("requests").doc(requestId);
    await db.runTransaction(async (t) => {
      const reqSnap = await t.get(requestRef);
      if (!reqSnap.exists) {
        throw new HttpsError("not-found", "Request not found.");
      }
      const rd = reqSnap.data() || {};
      if (rd.bloodBankId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "You can only edit your own requests.",
        );
      }

      t.update(requestRef, {
        units,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { ok: true, units };
  } catch (err) {
    console.error("[updateRequestUnits] ERROR:", err);
    throw toHttpsError(err, "Failed to update request units.");
  }
});

/**
 * getRequestDonorResponses — hospital only; donors who accepted / rejected
 * (name, email, phoneNumber, pipeline fields).
 */
exports.getRequestDonorResponses = onCall(
  publicCallableOpts,
  async (request) => {
    try {
      const uid = requireAuth(request);
      const data = request.data || {};
      const requestId = nonEmptyString(data.requestId, "requestId");
      const includeLatestReports = data.includeLatestReports !== false;

      const userSnap = await db.collection("users").doc(uid).get();
      if (!userSnap.exists || userSnap.data().role !== "hospital") {
        throw new HttpsError(
          "permission-denied",
          "Only hospitals can view donor response lists.",
        );
      }

      const requestRef = db.collection("requests").doc(requestId);
      const requestSnap = await requestRef.get();
      if (!requestSnap.exists) {
        throw new HttpsError("not-found", "Request not found.");
      }
      if (requestSnap.data().bloodBankId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "You can only view responses for your own requests.",
        );
      }

      const responsesSnap = await requestRef.collection("donorResponses").get();
      const accepted = [];
      const rejected = [];
      const entries = await buildDonorManagementEntries(responsesSnap.docs, {
        includeLatestReports,
      });

      for (let i = 0; i < responsesSnap.docs.length; i++) {
        const doc = responsesSnap.docs[i];
        const st = (doc.data() || {}).status;
        const entry = entries[i];
        if (st === "accepted") {
          accepted.push(entry);
        } else if (st === "rejected") {
          rejected.push(entry);
        }
      }

      return { ok: true, accepted, rejected };
    } catch (err) {
      console.error("[getRequestDonorResponses] ERROR:", err);
      throw toHttpsError(err, "Failed to load donor responses.");
    }
  },
);

/**
 * deleteRequest - delete a blood request (hospitals only, must own the request).
 */
exports.deleteRequest = onCall(publicCallableOpts, async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data || {};
    const requestId = nonEmptyString(data.requestId, "requestId");

    console.log(
      "[deleteRequest] Called with Request ID:",
      requestId,
      "by User UID:",
      uid,
    );

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};
    if (!userSnap.exists || userData.role !== "hospital") {
      throw new HttpsError(
        "permission-denied",
        "Only hospitals can delete requests.",
      );
    }

    const requestRef = db.collection("requests").doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }

    const requestData = requestSnap.data() || {};
    if (requestData.bloodBankId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You can only delete your own requests.",
      );
    }

    const { notificationsDeleted } = await deleteRequestCascade(
      requestRef,
      requestId,
    );
    console.log("[deleteRequest] Request document deleted from Firestore");

    const parts = ["Request and messages deleted"];
    if (notificationsDeleted > 0) {
      parts.push(`${notificationsDeleted} notification(s)`);
    }
    const message =
      parts.length > 1
        ? `${parts[0]}; ${parts.slice(1).join("; ")} successfully.`
        : "Request and messages deleted successfully.";

    return {
      ok: true,
      message,
      notificationsDeleted,
      medicalReportsDeleted: 0,
    };
  } catch (err) {
    console.error("[deleteRequest] ERROR:", err);
    throw toHttpsError(
      err,
      `Failed to delete request: ${err.message || "Unknown error"}`,
    );
  }
});

/**
 * cleanupExpiredRequests - deletes requests older than 7 days.
 */
exports.cleanupExpiredRequests = onSchedule(
  {
    schedule: "30 3 * * *",
    timeZone: "Asia/Amman",
    region: "us-central1",
  },
  async () => {
    try {
      const cutoff = Date.now() - REQUEST_TTL_MS;
      const snapshot = await db.collection("requests").get();
      let deleted = 0;
      for (const doc of snapshot.docs) {
        const data = doc.data() || {};
        const createdAt = data.createdAt;
        if (!createdAt || typeof createdAt.toMillis !== "function") continue;
        if (createdAt.toMillis() > cutoff) continue;
        await deleteRequestCascade(doc.ref, doc.id);
        deleted += 1;
      }
      console.log(`[cleanupExpiredRequests] done. deleted=${deleted}`);
      return null;
    } catch (err) {
      console.error("[cleanupExpiredRequests] ERROR:", err);
      return null;
    }
  },
);

/**
 * Normalizes governorate strings for comparison (spacing, apostrophes, case).
 */
function normalizeGovernorateLabel(s) {
  return (s || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ")
    .replace(/[\u2018\u2019]/g, "'");
}

/**
 * True if donor and hospital are in the same governorate (loose match).
 */
function donorMatchesHospitalLocation(donorData, hospitalLocationRaw) {
  const hospitalLocation = (hospitalLocationRaw || "").trim();
  if (!hospitalLocation) {
    return true;
  }
  const donorLocation = (donorData.location || "").trim();
  if (!donorLocation) {
    return true;
  }
  const a = normalizeGovernorateLabel(donorLocation);
  const b = normalizeGovernorateLabel(hospitalLocation);
  if (a === b) return true;
  if (a.length >= 2 && b.length >= 2 && (a.includes(b) || b.includes(a))) {
    return true;
  }
  return false;
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

function normalizeBloodTypeForMatch(s) {
  if (s == null) return "";
  return String(s).trim().toUpperCase().replace(/\s+/g, "");
}

/** First non-empty blood-type string on the donor user doc (legacy keys included). */
function donorProfileBloodTypeRaw(donorData) {
  if (!donorData || typeof donorData !== "object") return "";
  const keys = ["bloodType", "BloodType", "blood_group", "bloodGroup", "abo"];
  for (const k of keys) {
    const v = donorData[k];
    if (v == null) continue;
    const s = String(v).trim();
    if (s) return s;
  }
  return "";
}

/** True when the donor explicitly has no usable type (still gets all request alerts). */
function isDonorBloodMarkedUnknown(raw) {
  const t = normalizeBloodTypeForMatch(raw);
  if (!t) return true;
  return (
    t === "UNKNOWN" ||
    t === "N/A" ||
    t === "NA" ||
    t === "?" ||
    t === "NOTSET" ||
    t === "UNSET" ||
    t === "NONE"
  );
}

/**
 * Maps profile/request strings to one of STANDARD_BLOOD_TYPES, or null if absent
 * or not confidently parseable (e.g. single letter "B" without Rh).
 */
function canonicalStandardBloodType(raw) {
  if (raw == null) return null;
  let s = String(raw).trim();
  if (!s) return null;
  s = s.toUpperCase().replace(/\s+/g, "");
  s = s.replace(/\uFF0B/g, "+").replace(/\uFF0D/g, "-");
  s = s.replace(/POSITIVE/g, "+").replace(/NEGATIVE/g, "-");
  s = s.replace(/POS$/g, "+").replace(/NEG$/g, "-");
  if (STANDARD_BLOOD_TYPES.has(s)) return s;

  const m = s.match(/^(A|B|AB|O)([+-])$/);
  if (m) {
    const key = m[1] + m[2];
    if (STANDARD_BLOOD_TYPES.has(key)) return key;
  }
  return null;
}

/**
 * True if the donor should get a push/in-app notification for this request:
 * - Donor has no blood type on file (empty / missing): notify (unknown).
 * - Donor blood type cannot be confidently normalized: treat as unknown and notify.
 * - Otherwise: notify only when donor type matches request type.
 * If the request blood type is not a standard value, all donors are notified (legacy safety).
 */
/**
 * Returns the list of blood types that [donorType] can donate TO.
 * Based on standard blood donation compatibility rules.
 */
function compatibleRequestBloodTypes(donorType) {
  switch (donorType) {
    case "O-":
      return ["O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"];
    case "O+":
      return ["O+", "A+", "B+", "AB+"];
    case "A-":
      return ["A-", "A+", "AB-", "AB+"];
    case "A+":
      return ["A+", "AB+"];
    case "B-":
      return ["B-", "B+", "AB-", "AB+"];
    case "B+":
      return ["B+", "AB+"];
    case "AB-":
      return ["AB-", "AB+"];
    case "AB+":
      return ["AB+"];
    default:
      return null;
  }
}

/**
 * True if the donor should get a push/in-app notification for this request.
 * Uses medical blood type compatibility (not exact match).
 */
function donorMatchesRequestBloodType(donorData, requestBloodTypeRaw) {
  const donorRaw = donorProfileBloodTypeRaw(donorData);
  const reqCanon = canonicalStandardBloodType(requestBloodTypeRaw);

  if (!donorRaw || isDonorBloodMarkedUnknown(donorRaw)) {
    return true;
  }

  const donorCanon = canonicalStandardBloodType(donorRaw);
  if (!donorCanon) {
    return true;
  }

  if (!reqCanon) {
    return true;
  }

  // Check medical compatibility: can this donor donate to the request blood type?
  const compatible = compatibleRequestBloodTypes(donorCanon);
  if (!compatible) return true;

  return compatible.includes(reqCanon);
}

/**
 * Creates in-app notification docs, request messages, and FCM pushes for donors.
 * Called directly from addRequest (reliable). Filters by governorate (with fallback)
 * and by blood type (unknown blood type on profile still receives notifications).
 */
async function notifyDonorsForNewRequest(requestId, data) {
  if (!data || !requestId) {
    console.log("[notifyDonorsForNewRequest] Missing requestId or data, skip");
    return;
  }

  const isUrgent = coerceUrgent(data.isUrgent);

  const bloodType = data.bloodType;
  const bloodBankId = data.bloodBankId;
  const hospitalLocation = (data.hospitalLocation || "").trim();

  console.log(
    `[notifyDonorsForNewRequest] Request: ${requestId}, bloodType: ${bloodType}, ` +
      `hospitalLocation: ${hospitalLocation}, isUrgent: ${isUrgent}`,
  );

  const requestRef = db.collection("requests").doc(requestId);

  const allDonorsSnapshot = await db
    .collection("users")
    .where("role", "==", "donor")
    .get();

  let eligibleDonors = allDonorsSnapshot.docs.filter((doc) =>
    donorMatchesHospitalLocation(doc.data(), hospitalLocation),
  );

  if (!hospitalLocation) {
    console.log(
      "[notifyDonorsForNewRequest] No hospitalLocation set, notifying all donors " +
        `(eligible=${eligibleDonors.length})`,
    );
  }

  if (
    eligibleDonors.length === 0 &&
    allDonorsSnapshot.size > 0 &&
    hospitalLocation
  ) {
    console.warn(
      `[notifyDonorsForNewRequest] No governorate match for "${hospitalLocation}"; ` +
        "falling back to ALL donors so users still get notified.",
    );
    eligibleDonors = allDonorsSnapshot.docs;
  }

  const eligibleBeforeBlood = eligibleDonors.length;
  eligibleDonors = eligibleDonors.filter((doc) =>
    donorMatchesRequestBloodType(doc.data(), bloodType),
  );
  console.log(
    `[notifyDonorsForNewRequest] Blood-type filter: ${eligibleDonors.length} donors ` +
      `(before filter: ${eligibleBeforeBlood}, requestBlood=${bloodType})`,
  );

  console.log(
    `[notifyDonorsForNewRequest] Total donors: ${allDonorsSnapshot.size}, ` +
      `eligible for this request: ${eligibleDonors.length}`,
  );

  if (eligibleDonors.length === 0) {
    console.log(
      "[notifyDonorsForNewRequest] No donor users in database, nothing to send",
    );
    return;
  }

  const tokens = [];
  const MAX_BATCH_SIZE = 500;
  let notificationBatch = db.batch();
  let messageBatch = db.batch();
  let notificationBatchCount = 0;
  let messageBatchCount = 0;
  const batchPromises = [];

  for (const donorDoc of eligibleDonors) {
    const donorData = donorDoc.data();
    const donorId = donorDoc.id;

    const t = donorData.fcmToken;
    if (typeof t === "string" && t.trim().length > 0) {
      tokens.push(t.trim());
    }

    const notificationRef = db
      .collection("notifications")
      .doc(donorId)
      .collection("user_notifications")
      .doc();

    notificationBatch.set(notificationRef, {
      title: `Blood request: ${bloodType}`,
      body: `${data.bloodBankName || "Blood Bank"} needs your help ❤️`,
      requestId,
      isUrgent,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    notificationBatchCount++;

    if (notificationBatchCount >= MAX_BATCH_SIZE) {
      batchPromises.push(notificationBatch.commit());
      notificationBatch = db.batch();
      notificationBatchCount = 0;
    }
  }

  for (const donorDoc of eligibleDonors) {
    const donorData = donorDoc.data();
    const donorId = donorDoc.id;
    const donorName = donorData.fullName || donorData.name || "Donor";

    const messageRef = requestRef.collection("messages").doc();
    messageBatch.set(messageRef, {
      senderId: bloodBankId,
      senderRole: "hospital",
      text: `Please ${donorName}, ${data.bloodBankName || "Blood Bank"} needs your help ❤️`,
      recipientId: donorId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    messageBatchCount++;

    if (messageBatchCount >= MAX_BATCH_SIZE) {
      batchPromises.push(messageBatch.commit());
      messageBatch = db.batch();
      messageBatchCount = 0;
    }
  }

  if (notificationBatchCount > 0) {
    batchPromises.push(notificationBatch.commit());
  }
  if (messageBatchCount > 0) {
    batchPromises.push(messageBatch.commit());
  }
  if (batchPromises.length > 0) {
    await Promise.all(batchPromises);
  }

  console.log(
    `[notifyDonorsForNewRequest] Created ${eligibleDonors.length} notifications and messages`,
  );

  const uniqueTokens = [...new Set(tokens)].filter(
    (t) => typeof t === "string" && t.trim().length > 0,
  );

  async function sendInChunks(arr, size, fn) {
    for (let i = 0; i < arr.length; i += size) {
      await fn(arr.slice(i, i + size));
    }
  }

  if (uniqueTokens.length > 0) {
    const title = isUrgent ? "Urgent blood request" : "New blood request";
    const body = `${data.bloodBankName || "Blood Bank"} needs ${
      data.units || ""
    } units (${bloodType})`;

    const androidNotification = {
      channelId: isUrgent
        ? "emergency_request_channel_v4"
        : "normal_request_channel",
      icon: "ic_launcher",
      sound: isUrgent ? "emergency_request" : "normal_request",
      defaultSound: false,
      defaultVibrateTimings: false,
    };
    if (isUrgent) {
      androidNotification.vibrateTimingsMillis = [0, 500, 250, 500];
    }

    const message = {
      notification: { title, body },
      data: {
        type: "request",
        requestId: String(requestId),
        bloodType: String(bloodType || ""),
        isUrgent: isUrgent ? "true" : "false",
        title: String(title),
        body: String(body),
      },
      android: {
        priority: "high",
        notification: androidNotification,
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: isUrgent ? "emergency_request.mp3" : "normal_request.mp3",
            "interruption-level": isUrgent ? "time-sensitive" : "active",
            badge: 1,
          },
        },
      },
    };

    await sendInChunks(uniqueTokens, 500, async (chunk) => {
      const messages = chunk.map((token) => ({ ...message, token }));
      try {
        const res = await admin.messaging().sendAll(messages);
        console.log(
          `[Push] sent: ${res.successCount}, failed: ${res.failureCount}`,
        );
        res.responses.forEach((r, idx) => {
          if (!r.success) {
            console.log(
              "[Push] failed token:",
              chunk[idx],
              r.error ? r.error.message : "",
            );
          }
        });
      } catch (err) {
        console.error("[Push] Error sending messages:", err);
        for (const token of chunk) {
          try {
            await admin.messaging().send({ ...message, token });
          } catch (individualErr) {
            console.log(
              "[Push] Failed for token:",
              token,
              individualErr.message,
            );
          }
        }
      }
    });
  } else {
    console.log(
      `[Push] No FCM tokens among ${eligibleDonors.length} notified donors (in-app notifications still written).`,
    );
  }

  console.log(
    `[notifyDonorsForNewRequest] Done. Eligible: ${eligibleDonors.length}, ` +
      `FCM tokens: ${uniqueTokens.length}, location="${hospitalLocation}".`,
  );
}

function buildAutoGeneratedRequestId() {
  const rand = Math.random().toString(36).slice(2, 8);
  return `${Date.now()}_${rand}`;
}

/**
 * Creates a new request post and sends it to donors filtered by blood type/location.
 * Used by donor medical-report flow to generate a follow-up post after donation.
 */
exports.createAndBroadcastFollowUpRequest = async ({
  bloodBankId,
  bloodBankName,
  bloodType,
  units = 1,
  isUrgent = false,
  hospitalLocation = "",
  hospitalLatitude = null,
  hospitalLongitude = null,
  details = "",
  sourceRequestId = null,
  sourceReportId = null,
}) => {
  const requestId = buildAutoGeneratedRequestId();
  const normalizedUnits =
    typeof units === "number" && Number.isFinite(units) && units > 0
      ? Math.floor(units)
      : 1;
  const payload = {
    bloodBankId: String(bloodBankId || "").trim(),
    bloodBankName: String(bloodBankName || "Blood Bank").trim(),
    bloodType: String(bloodType || "").trim(),
    units: normalizedUnits,
    isUrgent: coerceUrgent(isUrgent),
    details: String(details || "").trim(),
    hospitalLocation: String(hospitalLocation || "").trim(),
    hospitalLatitude:
      typeof hospitalLatitude === "number" ? hospitalLatitude : null,
    hospitalLongitude:
      typeof hospitalLongitude === "number" ? hospitalLongitude : null,
    acceptedCount: 0,
    rejectedCount: 0,
    isCompleted: false,
    completedAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    autoGeneratedFromMedicalReport: true,
    sourceRequestId: sourceRequestId ? String(sourceRequestId) : null,
    sourceReportId: sourceReportId ? String(sourceReportId) : null,
  };

  await db.collection("requests").doc(requestId).set(payload);
  await notifyDonorsForNewRequest(requestId, payload);
  return { requestId };
};
