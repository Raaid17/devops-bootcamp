# CI/CD 4 — GHCR, Self-hosted Runner, Auto-deploy

Repo: `Raaid17/ship-dashboard` (fork `Infratify/ship-dashboard`)
Branch: `add-containerize` · workflow `.github/workflows/containerize.yaml`

LIFTOFF: pipeline **bina image → tolak ke GHCR → deploy ke EC2 saya sendiri**.
Ini automasi kerja yang dulu saya buat tangan masa sesi Docker + AWS.

## Workflow penuh

```yaml
name: containerize
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
      - run: npm clean-install
      - run: npm run test

  build-push:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.repository_owner }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v7
        with:
          context: .
          push: true
          tags: ghcr.io/raaid17/ship-dashboard:latest

  deploy:
    needs: build-push
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v7
      - run: docker compose up -d --pull always

permissions:
  packages: write
```

Rantaian: `test` → `build-push` → `deploy`, disambung dengan `needs:`.

## GHCR (GitHub Container Registry)

Registry percuma GitHub — ganti ECR untuk projek ni.

- **`secrets.GITHUB_TOKEN` tak perlu dicipta.** Actions jana sendiri setiap run,
  luput bila run habis. Tapi dia baca-sahaja secara lalai — sebab tu perlu
  `permissions: packages: write` supaya boleh push image.
- `docker/login-action` = `docker login ghcr.io` versi Actions.
- `docker/build-push-action` = `docker build` + `docker push` dalam satu step
  (guna Buildx, ada cache, boleh multi-arch).
- `context: .` = folder yang jadi build context (tempat `Dockerfile` dibaca).

### ⚠️ Perangkap terbesar: nama image WAJIB huruf kecil

Mula-mula saya tulis:

```yaml
tags: ghcr.io/${{ github.repository }}:latest
```

`github.repository` = `Raaid17/ship-dashboard` — ada **huruf besar**, dan
Docker/OCI tak benarkan huruf besar dalam nama repository image. Run gagal:
`invalid reference format: repository name must be lowercase`.

Ambil masa 3–4 commit nak selesai (`fix tags lowercase`, `fix tags lowercase 2`,
`test lowercase image name automation`, akhirnya `change image name to lowercase`).
Penyelesaian saya: tulis terus huruf kecil — `ghcr.io/raaid17/ship-dashboard:latest`.

Cara automatik kalau nak elak hardcode:

```yaml
      - id: repo
        run: echo "name=${GITHUB_REPOSITORY,,}" >> "$GITHUB_OUTPUT"   # ,, = lowercase bash
      - uses: docker/build-push-action@v7
        with:
          tags: ghcr.io/${{ steps.repo.outputs.name }}:latest
```

### Visibiliti package

Image baharu di GHCR = **private** secara lalai. Kalau server tarik tanpa login
→ `denied`. Dua pilihan:
1. Package → Settings → Change visibility → **Public** (yang saya buat), atau
2. `docker login ghcr.io` di server guna PAT (`read:packages`).

## Self-hosted runner

`ubuntu-latest` ialah VM GitHub — dia takkan boleh masuk EC2 saya. Jadi saya
pasang runner **atas EC2 itu sendiri**, dan runner tarik kerja keluar
(outbound) — tak perlu buka port masuk, tak perlu simpan kunci SSH.

Settings → Actions → Runners → **New self-hosted runner** (Linux x64), ikut
arahan yang dipaparkan:

```bash
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64.tar.gz -L <url-dari-halaman-github>
tar xzf actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/Raaid17/ship-dashboard --token <token>
./run.sh                    # ujian depan mata

sudo ./svc.sh install       # jadikan service supaya kekal hidup
sudo ./svc.sh start
sudo ./svc.sh status
```

Runner saya: `ip-172-31-5-241`, label `self-hosted, Linux, X64`.
Semak dari terminal:

```bash
gh api repos/Raaid17/ship-dashboard/actions/runners
```

`runs-on: self-hosted` = pilih runner ikut **label**. Runner offline → job
tergantung *Queued* sampai runner naik semula (bukan gagal terus).

⚠️ **Jangan** pakai self-hosted runner pada repo awam yang terima PR dari fork —
orang luar boleh jalankan kod atas server anda. Runner juga **tak** bersih
selepas guna (tak macam VM GitHub), jadi sampah build terkumpul.

## Auto-deploy

Job `deploy` jalan atas EC2, jadi `docker compose` yang dipanggil ialah Docker
pada server itu:

```bash
docker compose up -d --pull always
```

`compose.yaml` dalam repo:

```yaml
services:
  board:
    image: ghcr.io/raaid17/ship-dashboard:latest
    ports:
      - "80:3000"
    environment:
      SHIPIT_TOKEN: infratify
```

- **`--pull always` adalah kunci.** Tag kekal `:latest`, jadi tanpa flag ni
  Compose akan guna image lama yang dah ada dalam cache — deploy nampak hijau
  tapi tiada apa berubah.
- `checkout` masih perlu dalam job `deploy` supaya `compose.yaml` ada atas server.
- `80:3000` — port 80 hos ke port 3000 container (app dengar 3000 dalam image).
  Security group EC2 kena buka 80.
- Container ada `HEALTHCHECK` dalam Dockerfile; `docker ps` tunjuk `healthy`.

## Aliran penuh

```
git push
  → test (VM GitHub)
  → build-push (VM GitHub) → docker build → ghcr.io/raaid17/ship-dashboard:latest
  → deploy (EC2 saya)      → compose up -d --pull always → papan hidup di port 80
```

## Rollback

`:latest` tak boleh rollback — dia sentiasa tunjuk yang terbaru. Untuk boleh
undur, tag ikut commit:

```yaml
tags: |
  ghcr.io/raaid17/ship-dashboard:latest
  ghcr.io/raaid17/ship-dashboard:${{ github.sha }}
```

Kemudian di server: tukar tag dalam `compose.yaml` ke SHA lama → `up -d`.

## Command sesi ni

```bash
git checkout -b add-containerize
nano .github/workflows/containerize.yaml
git push -u origin add-containerize
gh run watch
gh run view --log-failed              # baca ralat lowercase tadi
docker compose ps                     # di EC2
docker compose logs -f board
```
