# CI/CD 2 — Gate Test & Branch Protection

Branch: `add-test` (PR #2) → `split-jobs` (PR #3)

## Idea besar

Pipeline bukan setakat deploy — dia kena boleh **halang** deploy bila kerja rosak.
Yang halang tu bukan "test" itu sendiri, tapi **exit code**.

```
exit 0   = lulus  → step seterusnya jalan
exit ≠ 0 = gagal  → job merah, semua step lepas tu DIBATAL
```

## Amali 1 — tambah gate (branch `add-test`)

Satu baris je ditambah, sebelum `npm run build`:

```yaml
      - run: npm clean-install
      - run: npm run test        # ← gate
      - run: npm run build
```

Dalam `launchpad/package.json`:

```json
"test": "node scripts/preflight.mjs"
```

`preflight.mjs` bukan unit test — dia **validate** `ship.config.json`:
nama kosong / lebih 24 aksara, hex warna salah, `shipModel` atau `emblem`
tak dikenali → `process.exit(1)` → **ABORT**, kapal terkandas atas pad.

Cara saya uji merah: sengaja rosakkan warna jadi `"#zzz"` → push → run merah,
step `build` dan `deploy-pages` langsung tak jalan. Betulkan → hijau semula.

## Amali 2 — pecah jadi 2 job (branch `split-jobs`)

```yaml
name: deploy
on: [push, workflow_dispatch]
defaults:
  run:
    working-directory: launchpad

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
      - run: npm clean-install
      - run: npm run test

  deploy:
    needs: test              # ← tunggu test hijau dulu
    runs-on: ubuntu-latest
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

### `needs:` — kunci sesi ni

- Tanpa `needs:`, semua job jalan **serentak** (selari) — deploy boleh naik
  walaupun test tengah merah.
- Dengan `needs: test`, `deploy` cuma start bila `test` habis **hijau**.
  Test merah → `deploy` status *skipped*, bukan failed.

### Kenapa `checkout` + `npm clean-install` diulang?

Sebab **setiap job dapat runner (VM) baharu dan kosong**. Apa yang job `test`
muat turun tak wujud langsung dalam job `deploy`. Kalau nak kongsi fail antara
job kena guna `upload-artifact` / `download-artifact`.

Tukar dari 1 job → 2 job:
- ✅ graf pipeline jelas (nampak mana yang gagal terus)
- ✅ boleh guna `needs`, syarat `if:`, environment berasingan
- ❌ lambat sikit (setup diulang)

`defaults.run.working-directory` saya naikkan ke **paras atas** (luar `jobs:`)
supaya kedua-dua job dapat, tak payah tulis dua kali.

## Branch protection

Gate dalam YAML boleh dilangkau kalau orang push terus ke `main`. Jadi kunci di
peringkat repo — **Settings → Branches → Add branch ruleset** untuk `main`:

- ✅ Require a pull request before merging
- ✅ Require status checks to pass → pilih check **`test`**
- ✅ Block force pushes

Kesan: push terus ke `main` ditolak, dan butang **Merge** PR kelabu selagi
`test` belum hijau. Nama check = **nama job** dalam YAML (`test`), jadi kalau
tukar nama job, ruleset kena update.

## Command sesi ni

```bash
git checkout -b add-test
git commit -am "prelight test" && git push -u origin add-test
gh pr create --fill
gh pr checks            # tengok status check PR
gh pr merge --squash --delete-branch

git checkout main && git pull
git checkout -b split-jobs
# ... pecah job ...
git push -u origin split-jobs && gh pr create --fill
gh run view --log-failed   # baca log step yang merah je
```
