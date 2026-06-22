For flashing --> type "make flash" in root directory  

After flashing, don't forget to reset the board first in C12  

Konfigurasi untuk Demo :
1. sw0 dan sw1 untuk animasi led
    - 00 --> ping-pong full 16 bit
    - 01 --> simple blink
    - 10 --> ping pong 8 bit, kanan kiri
    - 11 --> ping pong 8 bit, mirroring

2. sw2 dan sw3 untuk 7 segment
    - 00 --> N/A
    - 01 --> N/A
    - 10 --> counter 0 - 9999
    - 11 --> counter all bit 0000 - 9999

3. sw15 untuk switch ke program2 -- membaca switch dan menampilkan di 7 segment
    - sw0 - sw14 sebagai input biner, kemudian ditampilkan di led 15 bit dan 7 segment