# Android yayın yapılandırması

Depo varsayılan olarak Google test reklamlarını kullanır. Gerçek yayın değerleri veya imzalama anahtarı içermez.

1. `lib/core/app_config.dart` içindeki örnek iletişim değerini değiştirin; `assets/privacy_tr.txt` yerine yayımlayacağınız uygulamaya ait gizlilik metnini ekleyin.
2. Android imzalama anahtarınızı depo dışında saklayın. Yerel `android/key.properties` dosyasında `storeFile`, `storePassword`, `keyAlias` ve `keyPassword` değerlerini yapılandırın. Bu dosya Git tarafından yok sayılır.
3. Ortam değişkenleriyle `ORBIT_PRIVACY_URL`, `ORBIT_ADMOB_APP_ID`, `ORBIT_ADMOB_BANNER_ID`, `ORBIT_ADMOB_INTERSTITIAL_ID` ve `ORBIT_ADMOB_REWARDED_ID` değerlerini sağlayın.
4. `dart run tool/build_release.dart` komutunu çalıştırın. Araç eksik veya test reklam kimliklerini ve eksik imzalama dosyasını reddeder.
5. Gerçek Android cihazda reklam/UMP, ses, duraklatma ve yeniden başlatma akışlarını kontrol edin.

APK/AAB, özel ayarlar ve imzalama dosyalarını kaynak deposuna eklemeyin. Uygulama kimliği `com.emredev.orbitjump` olarak korunmuştur; kendi uygulamanız olarak dağıtacaksanız kendinize ait uygulama kimliğini kullanın.
