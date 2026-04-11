const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
admin.initializeApp();

// ─────────────────────────────────────────────
// YARDIMCI: Geçersiz tokenları Firestore'dan sil
// ─────────────────────────────────────────────
async function cleanupInvalidTokens(responses, tokenDocs) {
  const deletePromises = [];

  responses.forEach((resp, index) => {
    if (!resp.success) {
      const errorCode = resp.error?.code;
      console.warn(`Hatalı token [${tokenDocs[index].id}]: ${errorCode}`);

      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        deletePromises.push(
          admin.firestore().collection("fcm_tokens").doc(tokenDocs[index].id).delete()
        );
      }
    }
  });

  if (deletePromises.length > 0) {
    await Promise.all(deletePromises);
    console.log(`${deletePromises.length} geçersiz token silindi.`);
  }
}

// ─────────────────────────────────────────────
// YARDIMCI: Android + iOS mesaj yapısı oluştur
// ─────────────────────────────────────────────
function buildMessage(title, body, tokens) {
  return {
    tokens,
    notification: { title, body },
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };
}

// ─────────────────────────────────────────────
// 0. ESKİ TOKEN TEMİZLİĞİ (YENİ)
// 10 günü geçmiş (lastUpdate) tokenları siler
// ─────────────────────────────────────────────
exports.cleanupOldTokens = onSchedule(
  { schedule: "0 3 * * *", timeZone: "Europe/Istanbul" }, // Her gece 03:00
  async (event) => {
    console.log("--- ESKİ TOKEN TEMİZLİĞİ BAŞLADI ---");

    const tenDaysAgo = new Date();
    tenDaysAgo.setDate(tenDaysAgo.getDate() - 10);

    const oldTokensSnapshot = await admin.firestore()
      .collection("fcm_tokens")
      .where("lastUpdate", "<", admin.firestore.Timestamp.fromDate(tenDaysAgo))
      .get();

    if (oldTokensSnapshot.empty) {
      console.log("Silinecek eski token bulunamadı.");
      return;
    }

    const batch = admin.firestore().batch();
    oldTokensSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`${oldTokensSnapshot.size} adet 10 günden eski token temizlendi.`);
  }
);

// ─────────────────────────────────────────────
// 1. GENEL HATIRLATICI
// Her gün 14:00'de çalışır
// Topic bazlı — Flutter tarafındaki unsubscribeFromTopic halleder
// ─────────────────────────────────────────────
exports.dailyGeneralReminder = onSchedule(
  { schedule: "0 14 * * *", timeZone: "Europe/Istanbul" }, // ✅ Dakika 0 = sadece 1 kez
  async (event) => {
    console.log("--- GENEL HATIRLATICI TETİKLENDİ ---");

    const snapshot = await admin.firestore().collection("fcm_tokens").get();
    if (snapshot.empty) {
      console.log("Token bulunamadı.");
      return;
    }

    const tokenDocs = snapshot.docs
      .map(doc => ({ id: doc.id, token: doc.data().token }))
      .filter(t => t.token != null);

    // ✅ Bildirimleri kapatmış kullanıcıları filtrele
    const activeTokenDocs = [];
    await Promise.all(
      tokenDocs.map(async (tokenDoc) => {
        const userDoc = await admin.firestore().collection("users").doc(tokenDoc.id).get();
        const notificationsActive = userDoc.exists
          ? (userDoc.data().notifications_active ?? true)
          : true;

        if (notificationsActive) {
          activeTokenDocs.push(tokenDoc);
        } else {
          console.log(`Kullanıcı [${tokenDoc.id}] bildirimleri kapatmış, atlanıyor.`);
        }
      })
    );

    if (activeTokenDocs.length === 0) {
      console.log("Aktif bildirim kullanıcısı bulunamadı.");
      return;
    }

    const tokens = activeTokenDocs.map(t => t.token);
    const message = buildMessage(
      "Güne Hazır mısın? 🚀",
      "Bugünkü kelime testini çöz, serini koru!",
      tokens
    );

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Başarı: ${response.successCount}, Hata: ${response.failureCount}`);
    await cleanupInvalidTokens(response.responses, activeTokenDocs);
  }
);

// ─────────────────────────────────────────────
// 2. İNAKTİF KULLANICI
// Her gün 19:00'da çalışır
// ─────────────────────────────────────────────
exports.inactiveUserCheck = onSchedule(
  { schedule: "0 19 * * *", timeZone: "Europe/Istanbul" }, // ✅ Dakika 0 = sadece 1 kez
  async (event) => {
    console.log("--- İNAKTİF KULLANICI KONTROLÜ TETİKLENDİ ---");

    const twoDaysAgo = new Date();
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);

    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("last_quiz_date", "<", admin.firestore.Timestamp.fromDate(twoDaysAgo))
      .get();

    if (usersSnapshot.empty) {
      console.log("İnaktif kullanıcı bulunamadı.");
      return;
    }

    const promises = usersSnapshot.docs.map(async (userDoc) => {
      // ✅ Bildirimleri kapatmış kullanıcıyı atla
      const notificationsActive = userDoc.data().notifications_active ?? true;
      if (!notificationsActive) {
        console.log(`Kullanıcı [${userDoc.id}] bildirimleri kapatmış, atlanıyor.`);
        return;
      }

      const tokenDoc = await admin.firestore()
        .collection("fcm_tokens")
        .doc(userDoc.id)
        .get();

      if (!tokenDoc.exists || !tokenDoc.data().token) {
        console.log(`Kullanıcı [${userDoc.id}] için token bulunamadı.`);
        return;
      }

      const message = buildMessage(
        "Seni Özledik! 👋",
        "Geri dön ve serini kurtar!",
        [tokenDoc.data().token]
      );

      try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Kullanıcı [${userDoc.id}] bildirimi gönderildi.`);
        await cleanupInvalidTokens(response.responses, [{ id: userDoc.id }]);
      } catch (e) {
        console.error(`Kullanıcı [${userDoc.id}] bildirimi gönderilemedi:`, e);
      }
    });

    await Promise.all(promises);
  }
);

// ─────────────────────────────────────────────
// 3. GÜNLÜK HEDEF
// Her gün 20:00'de çalışır
// ─────────────────────────────────────────────
exports.dailyGoalReminder = onSchedule(
  { schedule: "0 20 * * *", timeZone: "Europe/Istanbul" }, // ✅ Dakika 0 = sadece 1 kez
  async (event) => {
    console.log("--- GÜNLÜK HEDEF KONTROLÜ TETİKLENDİ ---");

    const now = new Date();
    const dateId = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, "0")}-${now.getDate().toString().padStart(2, "0")}`;
    console.log(`Kontrol edilen tarih: ${dateId}`);

    const usersSnapshot = await admin.firestore().collection("users").get();
    if (usersSnapshot.empty) {
      console.log("Hiç kullanıcı bulunamadı.");
      return;
    }

    const promises = usersSnapshot.docs.map(async (userDoc) => {
      const userData = userDoc.data();

      // ✅ Bildirimleri kapatmış kullanıcıyı atla
      const notificationsActive = userData.notifications_active ?? true;
      if (!notificationsActive) {
        console.log(`Kullanıcı [${userDoc.id}] bildirimleri kapatmış, atlanıyor.`);
        return;
      }

      const dailyGoal = userData.daily_goal || 0;
      console.log(`Kullanıcı [${userDoc.id}] - daily_goal: ${dailyGoal}`);

      if (dailyGoal === 0) {
        console.log(`Kullanıcı [${userDoc.id}] hedef belirlememiş, atlanıyor.`);
        return;
      }

      const dailyRef = await admin.firestore()
        .collection("users")
        .doc(userDoc.id)
        .collection("daily_series")
        .doc(dateId)
        .get();

      const correctAnswers = dailyRef.exists ? (dailyRef.data().correct_answers || 0) : 0;
      const remaining = dailyGoal - correctAnswers;
      console.log(`Kullanıcı [${userDoc.id}] - correct_answers: ${correctAnswers}, kalan: ${remaining}`);

      if (remaining <= 0) {
        console.log(`Kullanıcı [${userDoc.id}] hedefini tamamlamış, atlanıyor.`);
        return;
      }

      const tokenDoc = await admin.firestore()
        .collection("fcm_tokens")
        .doc(userDoc.id)
        .get();

      if (!tokenDoc.exists || !tokenDoc.data().token) {
        console.log(`Kullanıcı [${userDoc.id}] için token bulunamadı.`);
        return;
      }

      const message = buildMessage(
        "Hedefine Az Kaldı! 🔥",
        `${remaining} kelime daha öğren, hedefe ulaş!`,
        [tokenDoc.data().token]
      );

      try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Kullanıcı [${userDoc.id}] bildirimi gönderildi.`);
        await cleanupInvalidTokens(response.responses, [{ id: userDoc.id }]);
      } catch (e) {
        console.error(`Kullanıcı [${userDoc.id}] bildirimi gönderilemedi:`, e);
      }
    });

    await Promise.all(promises);
  }
);

// ─────────────────────────────────────────────
// 4. HAFTALIK SKOR SIFIRLAMA + ŞAMPİYONLARI KAYDETME
// Her Pazar gecesi 23:59'da çalışır
// ─────────────────────────────────────────────
exports.resetWeeklyScores = onSchedule(
  { schedule: "59 23 * * 0", timeZone: "Europe/Istanbul" },
  async (event) => {
    console.log("--- HAFTALIK SIFIRLAMA VE ŞAMPİYON KAYDI BAŞLADI ---");

    try {
      const db = admin.firestore();

      // A) ŞAMPİYONLARI BELİRLE (Sıfırlamadan hemen önce ilk 3'ü al)
      const topSnapshot = await db.collection("weekly_leaderboard")
        .orderBy("weeklyScore", "desc")
        .limit(3)
        .get();

      if (!topSnapshot.empty) {
        const championsBatch = db.batch();
        const championsRef = db.collection("last_week_champions");

        // Önce eski şampiyonları temizle (Her hafta taze veri olması için)
        const oldChampions = await championsRef.get();
        oldChampions.docs.forEach(doc => championsBatch.delete(doc.ref));

        // Yeni şampiyonları ekle
        topSnapshot.docs.forEach((doc, index) => {
          championsBatch.set(championsRef.doc(doc.id), {
            uid: doc.id,
            username: doc.data().username,
            avatar: doc.data().avatar || "assets/avatars/boy-avatar-1.png",
            score: doc.data().weeklyScore,
            rank: index + 1,
            savedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });
        await championsBatch.commit();
        console.log("Geçen haftanın şampiyonları başarıyla kaydedildi.");
      }

      // B) SKORLARI SIFIRLA
      // Sadece skoru 0'dan büyük olanları çekerek kota tasarrufu yapıyoruz
      const userSnapshot = await db.collection("users").where("weekly_score", ">", 0).get();
      const leaderboardSnapshot = await db.collection("weekly_leaderboard").where("weeklyScore", ">", 0).get();

      let batch = db.batch();
      let count = 0;
      const promises = [];

      // Users koleksiyonundaki haftalık skorları sıfırla
      userSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, { weekly_score: 0 });
        count++;
        if (count === 500) { promises.push(batch.commit()); batch = db.batch(); count = 0; }
      });

      // Weekly Leaderboard koleksiyonundaki skorları sıfırla
      leaderboardSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, { weeklyScore: 0 });
        count++;
        if (count === 500) { promises.push(batch.commit()); batch = db.batch(); count = 0; }
      });

      if (count > 0) promises.push(batch.commit());
      await Promise.all(promises);

      console.log("Haftalık tüm skorlar sıfırlandı ve yeni haftaya hazır hale getirildi.");
    } catch (error) {
      console.error("Sıfırlama işlemi sırasında hata oluştu:", error);
    }
  }
);

