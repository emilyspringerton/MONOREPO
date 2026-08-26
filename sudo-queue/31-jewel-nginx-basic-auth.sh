#!/usr/bin/env bash
# Exposes JEWEL (real PARENA Jupyter kernel/backend, jewel-jupyter.service on
# 127.0.0.1:8890) at https://okemily.com/jewel/, gated by HTTP Basic Auth.
#
# Founder real-time chain: "work on our parena JUPYTER backend just use
# basic auth to protect it for now until we get google oauthg to work" ->
# "call it JEWEL" -> "upstream github JEWEL created in case its useful" ->
# "put the parena backend for jupyter there". Basic Auth is a deliberate,
# explicit interim measure -- IDUNA's Google OAuth devportal gate is the
# real long-term story, blocked on a genuine human-only GCP Console step
# (see EMILY/BACKLOG.md's OAuth Client ID entry). JupyterLab itself has NO
# auth of its own (--ServerApp.token='' --ServerApp.password='', see
# JEWEL/ops/systemd/jewel-jupyter.service) -- this nginx auth_basic block is
# the ONLY real gate in front of it. Do not remove it without replacing it
# with something at least as strong first.
#
# The password hash below is a real SHA-256-crypt hash (htpasswd's own
# native format) -- one-way, safe to commit same as any real htpasswd file.
# The matching PLAINTEXT password was reported to the founder directly out
# of band (not committed anywhere in git) -- if it's been lost, generate a
# fresh one and re-run this script:
#   python3 -c "import crypt,secrets,string; pw=''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(24)); print(pw); print('jewel:' + crypt.crypt(pw, crypt.mksalt(crypt.METHOD_SHA256)))"
#
# Same "diff live against this repo's copy before overwriting" discipline
# OKEMILY/CLAUDE.md's own CRITICAL note demands (a blind sudo cp here has
# taken HTTPS down for real before, 2026-07-18) -- verified identical
# immediately before writing this script's own edits, so no drift to
# reconcile as of this writing; still diff again at run time below rather
# than trusting that stays true.
set -euo pipefail

if ! diff -q /home/fatbaby/OKEMILY/ops/nginx-okemily.conf /etc/nginx/sites-available/okemily >/dev/null 2>&1; then
    echo "REFUSING: live /etc/nginx/sites-available/okemily has diverged from"
    echo "OKEMILY/ops/nginx-okemily.conf since this script was written (likely a"
    echo "certbot renewal run). Re-sync the repo copy from the live file first,"
    echo "re-apply the /jewel/ location blocks on top of that, then re-run."
    diff /home/fatbaby/OKEMILY/ops/nginx-okemily.conf /etc/nginx/sites-available/okemily || true
    exit 1
fi

# htpasswd entry: user "jewel", password reported to the founder out of band.
printf 'jewel:$5$zgJl1DwlxKcqRA1V$stISBfUa5J09UuR/jDzo003JQ3SjR2ZrLoLlD.hRHd8\n' | sudo tee /etc/nginx/.htpasswd-jewel >/dev/null
sudo chmod 640 /etc/nginx/.htpasswd-jewel
sudo chown root:www-data /etc/nginx/.htpasswd-jewel

sudo cp /home/fatbaby/OKEMILY/ops/nginx-okemily.conf /etc/nginx/sites-available/okemily
sudo nginx -t
sudo systemctl reload nginx

echo "applied. verify with:"
echo "  curl -sI https://okemily.com/jewel/ | head -1                       # expect 401"
echo "  curl -su jewel:'<password>' -sI https://okemily.com/jewel/lab | head -1   # expect 200"
