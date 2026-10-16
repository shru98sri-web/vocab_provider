const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendAssessmentReport = onDocumentCreated(
  "assessment_reports/{reportId}",
  async (event) => {
    const d = event.data.data();
    if (!d || !d.fcmToken) return;

    await admin.messaging().send({
      token: d.fcmToken,
      notification: { title: d.title, body: d.body },
      data: { reportId: event.params.reportId, type: "assessment_report" },
      android: {
        priority: "high",
        notification: { channelId: "assessment_channel" },
      },
      apns: { payload: { aps: { sound: "default" } } },
    });
  }
);

