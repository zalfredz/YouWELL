# Produk web YouWell

Web adalah companion untuk aktivitas di depan laptop, bukan salinan mobile.

| Rute | Fungsi |
| --- | --- |
| `/#/` | Landing publik |
| `/#/app` | Home, Focus Station, Progress, Community |
| `/#/admin` | Workspace dengan tambahan antrean Community Admin |
| `/#/recap` | Ringkasan progress yang aman dibagikan |

Home memakai paket Daily Card dan progres yang sama dengan mobile. Focus Station tetap
menjadi tempat Pomodoro/sesi panjang; mobile hanya menyediakan quick focus.
Profile dibuka dari avatar kanan atas.

Community dan Admin tersedia sebagai prototype lokal. Post baru berstatus
`pending`; Admin dapat mengubahnya menjadi `approved` atau `rejected`. Saat
backend dipasang, keputusan ini harus dipindahkan ke role, RLS, audit log, dan
moderasi server—bukan dipercaya dari Flutter client.
