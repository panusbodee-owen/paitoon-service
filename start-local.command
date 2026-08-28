#!/bin/bash
cd "$(dirname "$0")"
echo "กำลังเริ่มเซิร์ฟเวอร์ ไพฑูรณ์ Service..."
echo "รอสักครู่ แล้วเปิดเบราว์เซอร์ไปที่ http://localhost:5173/paitoon-service/"
npm run dev
