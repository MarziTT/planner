# =============================================
# PixelPlanner ProGuard / R8 Keep Rules
# 修复 release 构建闪退：WorkManager + Room
# =============================================

# -------------------- WorkManager --------------------
# 保留所有 Worker 子类
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.work.CoroutineWorker { *; }

# WorkManager 内部数据库（解决 WorkDatabase 找不到的问题）
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.model.** { *; }
-keep class androidx.work.impl.background.systemjob.** { *; }
-keep class androidx.work.impl.background.systemalarm.** { *; }
-keep class androidx.work.impl.utils.** { *; }

# WorkManager WorkerFactory
-keep class * implements androidx.work.WorkerFactory { *; }

# -------------------- Room --------------------
# 保留 RoomDatabase 子类及其实现
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.RoomDatabase_Impl { *; }

# 保留 @Entity 注解的类
-keep @androidx.room.Entity class * { *; }
-keepclassmembers @androidx.room.Entity class * { *; }

# 保留 @Dao 注解的接口
-keep @androidx.room.Dao interface * { *; }

# 保留 Room 生成的实现类
-keep class **_Impl { *; }
-keep class * extends androidx.room.RoomDatabase_Impl { *; }

# Room 相关警告忽略
-dontwarn androidx.room.paging.**
-dontwarn androidx.room.**
-keepattributes *Annotation*

# -------------------- 通用 --------------------
# 保留序列化相关
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# OkHttp（项目中依赖了）
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
