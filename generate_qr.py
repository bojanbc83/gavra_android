#!/usr/bin/env python3
"""
QR Code generator za Gavra Android aplikaciju
"""

try:
    import qrcode
    from PIL import Image
except ImportError:
    print("Potrebno je instalirati: pip install qrcode[pil]")
    exit(1)

# GitHub release link
app_link = "https://github.com/bojanbc83/gavra_android/releases/tag/v1.0.0"

# Kreiranje QR koda
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=10,
    border=4,
)

qr.add_data(app_link)
qr.make(fit=True)

# Kreiranje slike
img = qr.make_image(fill_color="black", back_color="white")

# Čuvanje QR koda
img.save("gavra_android_qr.png")

print("✅ QR kod kreiran: gavra_android_qr.png")
print(f"📱 Link: {app_link}")
print("\n🔍 Kada korisnik skenira QR kod:")
print("1. Otvara se GitHub release stranica")
print("2. Korisnik vidi app-release.apk")
print("3. Klikne na APK za download")
print("4. APK se download-uje direktno")
