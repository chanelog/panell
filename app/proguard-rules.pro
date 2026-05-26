# Keep VPN service & callbacks
-keep class com.chanelog.zicustom.** { *; }
-keepclassmembers class * extends android.net.VpnService { *; }
