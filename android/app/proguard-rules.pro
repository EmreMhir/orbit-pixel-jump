# Room 2.2.5 (transitive through WorkManager/Ads) instantiates generated
# databases reflectively. Its class-only consumer rule does not retain the
# no-argument constructor in R8 full mode, crashing InitializationProvider
# before Flutter starts. Retain the constructor as well as the class name.
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}
