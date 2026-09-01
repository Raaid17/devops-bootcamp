# CI/CD 1 — Workflow, Job, Laman Pages

Repo: fork `Infratify/devops-bootcamp-shipit` → `Raaid17/devops-bootcamp-shipit`
Branch: `customize` → PR #1

## Apa itu workflow

Fail YAML dalam `.github/workflows/`. GitHub baca fail ni, dan setiap kali
ada **event** (cth: push), dia hidupkan satu **runner** (VM percuma dari GitHub)
untuk jalankan **job** yang ada di dalamnya.

```
event (push) → workflow → job → step → runner ubuntu-latest
```

- **workflow** = satu fail YAML = satu pipeline
- **job** = satu unit kerja, dapat runner/VM SENDIRI
- **step** = satu arahan dalam job, jalan turun ikut urutan
- **runner** = mesin yang jalankan job (`ubuntu-latest` = VM GitHub)

## Fail pertama saya

`.github/workflows/deploy.yaml` (guna `.yaml`, bukan `.yml`)

```yaml
name: deploy
on: [push, workflow_dispatch]
jobs:
  say-hello:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: launchpad
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
      - run: npm clean-install
      - run: npm run build
      - uses: actions/upload-pages-artifact@v5
        with:
          path: launchpad/dist
      - uses: actions/deploy-pages@v5

permissions:
  pages: write
  id-token: write
```

## Nota setiap baris

| Baris | Maksud |
|---|---|
| `name:` | nama workflow yang keluar di tab Actions |
| `on: [push, workflow_dispatch]` | bila nak jalan. `push` = auto, `workflow_dispatch` = butang **Run workflow** manual |
| `jobs:` | senarai job. `say-hello` tu nama saya bagi sendiri, bebas |
| `runs-on:` | jenis runner |
| `defaults.run.working-directory` | semua `run:` masuk folder `launchpad/` dulu — supaya tak payah `cd` setiap step |
| `uses:` | pakai action orang lain (dari Marketplace) |
| `run:` | arahan shell biasa |

**`uses` vs `run`** — `uses` = panggil action siap pakai, `run` = taip command sendiri.

## Perangkap yang saya kena

1. **`working-directory` TAK kena pada `uses:`.** Dia cuma untuk step `run:`.
   Sebab tu `upload-pages-artifact` kena tulis `path: launchpad/dist`, bukan `dist`.
2. **`permissions:` wajib** untuk deploy Pages —
   `pages: write` (izin tulis ke Pages) + `id-token: write` (OIDC token untuk
   `deploy-pages` sahkan diri). Tanpa dia → run merah "Resource not accessible".
3. **Settings → Pages → Source kena tukar ke "GitHub Actions"** (bukan "Deploy
   from a branch"). Kalau tak tukar, workflow hijau tapi laman tak naik.

## Aliran deploy Pages

```
checkout → setup-node → npm clean-install → npm run build (vite → dist/)
        → upload-pages-artifact (bungkus dist/ jadi artifact)
        → deploy-pages (ambil artifact, letak atas Pages)
```

`npm clean-install` (= `npm ci`) bukan `npm install` — dia ikut
`package-lock.json` bulat-bulat, jadi build CI konsisten.

## Hasil

Laman hidup: https://raaid17.github.io/devops-bootcamp-shipit/
Kapal saya (`launchpad/ship.config.json`):

```json
{ "shipName": "Raaid17", "color": "#46e3d1", "shipModel": "hauler", "emblem": "comet" }
```

## Command sesi ni

```bash
gh repo fork Infratify/devops-bootcamp-shipit --clone
git checkout -b customize
mkdir -p .github/workflows && nano .github/workflows/deploy.yaml
git add . && git commit -m "chore: customize config"
git push -u origin customize
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch          # tengok run berjalan dari terminal
gh run list -L 5
```
