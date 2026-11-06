# PokéPod release keep rules
# ==========================
#
# Why this file exists
# --------------------
# `shared_preferences_android` 2.5.x ships *jnigen-generated Dart* JNI bindings
# (`lib/src/messages.g.jni.dart` and `lib/src/messages_async.g.jni.dart`), and
# `package:jni` itself bridges Kotlin coroutines from Dart (`lib/src/kotlin.dart`).
# Both resolve Java/Kotlin members by handing *literal names and JNI descriptors*
# to `JClass.forName`, `instanceMethodId`, `staticFieldId`, ... for example:
#
#     SharedPreferencesApiRegistrar._class.instanceMethodId(
#       'getAll',
#       r'(Ljava/lang/String;Ljava/util/List;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;',
#     );
#     JClass.forName('kotlin/coroutines/intrinsics/CoroutineSingletons');
#
# Those literals are compiled into `libapp.so` (the Dart AOT snapshot), which R8
# never reads — R8 only shrinks and obfuscates the JVM dex. Every symbol named by
# such a literal therefore has to keep its original name *and* must not be
# removed as dead code.
#
# What was broken
# ---------------
# Release builds run R8 with minification (the Flutter Gradle plugin enables it
# for `release` by default), so R8 renamed/stripped the Kotlin runtime classes
# named above. `SharedPreferences.getInstance()` then failed *before* `runApp()`
# was ever called, first with:
#
#     java.lang.NoSuchMethodError: no non-static method
#       "Lio/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar;
#        .getAll(Ljava/lang/String;Ljava/util/List;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;"
#
# and, once that was corrected, with:
#
#     java.lang.ClassNotFoundException: Didn't find class
#       "kotlin/coroutines/intrinsics/CoroutineSingletons"
#
# The release APK installed and opened, but no widget was ever built, so it sat
# on a permanently blank screen. Debug builds are not minified, which is why only
# the release build was affected.
#
# Scope
# -----
# Only symbols referenced by name from `libapp.so` or from `libdartjni.so`
# (`com.github.dart_lang.jni.*`, already covered by that package's own
# `consumer-rules.pro`) are kept. R8 still shrinks, optimises and obfuscates the
# rest of the app — no protection is disabled and no build type is changed.

# --- Resolved by name by package:jni (lib/src/kotlin.dart) -------------------
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }

# --- Types appearing verbatim inside jnigen method descriptors ---------------
# (shared_preferences_android messages*.g.jni.dart)
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }
-keep class kotlin.enums.EnumEntries { *; }

# --- Plugin classes whose names/methods those bindings embed -----------------
# `Lio/flutter/plugins/sharedpreferences/...;`, `getAll`, `getInstance`,
# `clear`, ... Upstream already preserves them via `@Keep`; keeping them
# explicitly means a future Pigeon/jnigen regeneration cannot silently
# reintroduce the blank screen.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
