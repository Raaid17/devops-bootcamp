# CI/CD 3 — Secret & Variable

Branch: `lapor-papan` (PR #4) → `split-triggers`

## Secret vs Variable

Dua-dua letak di **Settings → Secrets and variables → Actions**.

| | Variable | Secret |
|---|---|---|
| Tab | Variables | Secrets |
| Panggil | `${{ vars.NAMA }}` | `${{ secrets.NAMA }}` |
| Boleh baca balik? | ✅ ya, nampak nilainya | ❌ tak, tulis je (write-only) |
| Dalam log | keluar apa adanya | ditapis jadi `***` |
| Untuk apa | config awam — URL, region, nama env | kata laluan, token, kunci API |

Punya saya:
- `BOARD_URL` → **variable** (alamat papan Mission Control, tak rahsia)
- `SHIPIT_TOKEN` → **secret** (token Bearer untuk hantar event)

```bash
gh variable set BOARD_URL --body "http://<alamat-papan>"
gh secret set SHIPIT_TOKEN          # prompt, tak masuk shell history
gh variable list
gh secret list                      # nampak nama + tarikh je, bukan nilai
```

## Amali — step lapor ke papan

Tarik dulu skrip baharu dari upstream (model fork):

```bash
gh repo sync Raaid17/devops-bootcamp-shipit
git pull
```

Kemudian tambah SATU step dalam job `test`:

```yaml
      - run: bash scripts/report.sh
        env:
          BOARD_URL: ${{ vars.BOARD_URL }}
          SHIPIT_TOKEN: ${{ secrets.SHIPIT_TOKEN }}
```

Blok `env:` inilah pelajarannya — satu baris `vars`, satu baris `secrets`.
Semua urusan HTTP duduk dalam `launchpad/scripts/report.sh`.

### Cara `env:` berfungsi

`env:` di bawah satu step = pemboleh ubah persekitaran untuk step itu sahaja.
Skrip baca `$BOARD_URL` / `$SHIPIT_TOKEN` macam biasa — dia langsung tak tahu
pasal GitHub. Boleh juga letak `env:` di paras job atau paras workflow (skop
makin luas). **Jangan** interpolasi secret terus dalam `run:` — hantar lalu
`env:`, supaya nilai tak terbenam dalam arahan shell.

### Yang datang percuma

`report.sh` tak perlu saya bagi callsign — Actions dah set sendiri:
`GITHUB_ACTOR` (= username saya), `GITHUB_REPOSITORY`,
`GITHUB_REPOSITORY_OWNER`. Dari situ dia bina `siteUrl` Pages sendiri.
`color` + `shipModel` pula dibaca dari `ship.config.json`.

Badan event yang dihantar:

```
POST $BOARD_URL/api/event
Authorization: Bearer $SHIPIT_TOKEN
{ "callsign":"Raaid17", "stage":"liftoff", "status":"shipped",
  "color":"#46e3d1", "shipModel":"hauler", "siteUrl":"https://raaid17.github.io/..." }
```

## Pelajaran token salah (401)

Token salah / tak set → papan balas `401 {"error":"unauthorized"}`.
`report.sh` guna `curl --fail-with-body`, jadi:
- exit code ≠ 0 → **step merah**
- badan respons tetap dicetak dalam log → nampak SEBAB dia merah

(`-f` biasa akan gagal tapi telan mesej ralat — sebab tu guna `--fail-with-body`.)

Dalam log, nilai secret keluar sebagai `***`. Tapi ingat: itu penapisan teks
sahaja — kalau skrip `base64` atau pecahkan token, penapis boleh terlepas.

## Nilai untuk build vs untuk runtime

Laman statik perlu tahu alamat papan juga, tapi build-time:

```yaml
      - run: npm run build
        env:
          VITE_BOARD_URL: ${{ vars.BOARD_URL }}
```

Vite benamkan `VITE_*` ke dalam bundle semasa build. Sebab tu **jangan sekali-kali
letak secret dalam `VITE_*`** — dia akan terbit dalam JS awam.

## Pecah trigger: push vs pull_request (branch `split-triggers`)

Masalah: saya nak **test jalan masa PR dibuka**, tapi **deploy jalan hanya
selepas PR digabung**.

```yaml
name: cicd
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

jobs:
  test:
    if: github.event.pull_request.merged == false
    ...
  deploy:
    needs: test
    if: always() && github.event.pull_request.merged == true
    ...
```

- `types:` — `opened` (PR dibuka), `synchronize` (push baharu ke PR),
  `reopened`, `closed` (ditutup ATAU digabung).
- `github.event.pull_request.merged` — cara bezakan "ditutup je" dengan
  "betul-betul digabung".
- **`always()` penting**: `deploy` ada `needs: test`, dan masa PR merge job
  `test` di-*skip*. Tanpa `always()`, job yang bergantung pada job skipped akan
  ikut skip juga. `always()` paksa dia nilai `if:` tu tetap.

Bentuk biasa (lagi ringkas) untuk repo peribadi:

```yaml
on:
  push:
    branches: [main]
  pull_request:
jobs:
  deploy:
    if: github.event_name == 'push'
```

## Kelulusan manual (environment)

`environment: production` pada job + **Settings → Environments → Required
reviewers** = pipeline berhenti dan tunggu saya tekan **Approve** sebelum
deploy. Environment juga boleh simpan secret/variable sendiri yang mengatasi
paras repo.

## Command sesi ni

```bash
gh repo sync && git pull
git checkout -b lapor-papan
gh variable set BOARD_URL --body "..."
gh secret set SHIPIT_TOKEN
git commit -am "tambah step lapor" && git push -u origin lapor-papan
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch
```
