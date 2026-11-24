#!/usr/bin/env python3
"""
scripts/colab_drive_home_link.py -- paste into ONE Colab cell (or `!python3 scripts/colab_drive_home_link.py`).

Founder real-time 2026-11-24: the Colab session runs as the `ubuntu` user (not the default root),
Google Drive mounts as root (at /content/drive, My Drive under it -- sometimes shown as
/content/MyDrive), and the home dir must sync into Drive: "the colab skrip where it auths into
google drive and sets up the symlinks from our home dir into the content root".

What it does, in order (every step prints what it did and what it could not do):
  1. reports who the kernel runs as, and whether sudo works without a password
  2. mounts Drive (Colab's own interactive auth popup -- the OAuth consent is a human click, it cannot
     be scripted). If the kernel is not root, it falls back to mounting as root via sudo, then makes the
     mount reachable by `ubuntu` (user_allow_other / remount) -- see the diagnostics it prints
  3. makes <MyDrive>/<DRIVE_DIR>/ (default MyDrive/ubuntu-home) -- the REAL home of the synced data
  4. for each name in LINKS: Drive holds the real directory, ~/<name> becomes a symlink into it, and
     /content/<name> is a second symlink to the same place (the "content root" link)
  5. never destroys data: an existing real ~/<name> is COPIED into Drive first (rsync, no --delete) and
     then renamed ~/<name>.pre-drive-link, not removed. Re-running is idempotent.

HONEST LIMITS (nothing here could be run in the authoring sandbox -- no Colab, no Drive):
  - Drive FUSE has no unix permissions, no hardlinks, no symlinks INSIDE Drive and is slow with many
    small files. So do NOT link .git-heavy trees you commit from (use the git-pull notebook
    scripts/monorepo_drive_sync.ipynb for repos) and never link ~/.ssh (Drive can't hold 0600 modes).
    The default LINKS are data-ish dirs; edit the list.
  - Do not run git against the same checkout from Drive and elsewhere at once (index corruption).
  - Colab VMs are ephemeral: the symlinks vanish with the VM, the Drive data stays. Re-run this cell.
  - Mounting as non-root depends on the image allowing passwordless sudo; the script says so if not.
"""
import getpass
import os
import shutil
import subprocess
import sys

# ----- config: edit these -------------------------------------------------------------------------
MOUNT      = '/content/drive'          # where Colab mounts Drive; My Drive is MOUNT/MyDrive
DRIVE_DIR  = 'ubuntu-home'             # folder inside My Drive that holds the real data
HOME       = os.path.expanduser('~ubuntu') if os.path.isdir('/home/ubuntu') else os.path.expanduser('~')
CONTENT    = '/content'                # the "content root" the second link goes into
LINKS      = ['work', 'data', 'models', 'checkpoints', 'notebooks', 'scratch']   # names under ~ to sync
NEVER      = {'.ssh', '.gnupg', '.git', '.config', '.cache', '.bashrc', '.profile'}  # refused outright
LINK_IN_CONTENT = True                 # also make /content/<name> -> Drive
# ---------------------------------------------------------------------------------------------------


def sh(cmd, check=False):
    r = subprocess.run(cmd, shell=isinstance(cmd, str), capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    if check and r.returncode:
        raise RuntimeError(f'{cmd!r} failed: {out}')
    return r.returncode, out


def log(msg):
    print(msg, flush=True)


def can_sudo():
    return sh('sudo -n true')[0] == 0


def mount_drive():
    """Return the My Drive path, mounting if needed."""
    for cand in (os.path.join(MOUNT, 'MyDrive'), '/content/MyDrive', os.path.join(MOUNT, 'My Drive')):
        if os.path.isdir(cand) and os.access(cand, os.W_OK):
            log(f'Drive already mounted and writable at {cand}')
            return cand
    try:
        from google.colab import drive   # interactive OAuth popup: a human click, by design
        drive.mount(MOUNT, force_remount=False)
    except Exception as e:               # not root, or kernel cannot mount: try the sudo route
        log(f'drive.mount() as {getpass.getuser()} failed: {type(e).__name__}: {e}')
        if not can_sudo():
            raise SystemExit('No passwordless sudo, so Drive cannot be mounted as root from this user. '
                             'Run the drive.mount cell in a root kernel once, then re-run this script '
                             '(it only needs the mount to be reachable and writable by ubuntu).')
        log('retrying the mount through sudo (root) ...')
        code = ("from google.colab import drive; drive.mount(%r)" % MOUNT)
        rc, out = sh(['sudo', '-n', sys.executable, '-c', code])
        log(out[-600:])
    for cand in (os.path.join(MOUNT, 'MyDrive'), '/content/MyDrive', os.path.join(MOUNT, 'My Drive')):
        if os.path.isdir(cand):
            if not os.access(cand, os.W_OK):
                log(f'{cand} is mounted but NOT writable by {getpass.getuser()} -- the FUSE mount is root-only.')
                if can_sudo():
                    log('trying: allow_other + chmod via sudo (best effort, FUSE may ignore chmod)')
                    sh("echo user_allow_other | sudo -n tee -a /etc/fuse.conf >/dev/null")
                    sh(['sudo', '-n', 'chmod', '-R', 'a+rwX', cand])
                if not os.access(cand, os.W_OK):
                    raise SystemExit(
                        f'{cand} is root-only. Fix: remount with allow_other, or run this script as root and '
                        f'create the links as ubuntu afterwards. Not fabricating success.')
            return cand
    raise SystemExit('Drive did not mount (no MyDrive directory found). Re-run and approve the auth popup.')


def rsync_into(src, dst):
    os.makedirs(dst, exist_ok=True)
    if shutil.which('rsync'):
        rc, out = sh(['rsync', '-a', '--no-perms', '--no-owner', '--no-group', src.rstrip('/') + '/', dst.rstrip('/') + '/'])
    else:
        rc, out = sh(['cp', '-a', '--no-preserve=mode,ownership', src.rstrip('/') + '/.', dst])
    if rc:
        raise RuntimeError(f'copy {src} -> {dst} failed: {out[-400:]}')


def link(src_real, dst_link):
    """dst_link -> src_real, replacing only an existing symlink; real things are never deleted."""
    if os.path.islink(dst_link):
        if os.path.realpath(dst_link) == os.path.realpath(src_real):
            return 'ok'
        os.unlink(dst_link)
    elif os.path.exists(dst_link):
        return 'EXISTS-not-a-link (left alone)'
    try:
        os.symlink(src_real, dst_link)
    except PermissionError:
        rc, out = sh(['sudo', '-n', 'ln', '-sfn', src_real, dst_link]) if can_sudo() else (1, 'no sudo')
        if rc:
            return f'FAILED ({out})'
    return 'linked'


def main():
    log(f'user={getpass.getuser()} uid={os.getuid()} home={HOME} sudo-nopasswd={can_sudo()}')
    mydrive = mount_drive()
    base = os.path.join(mydrive, DRIVE_DIR)
    os.makedirs(base, exist_ok=True)
    log(f'real data lives in: {base}')
    rows = []
    for name in LINKS:
        if name in NEVER or name.startswith('.') or '/' in name:
            rows.append((name, 'REFUSED (in NEVER list / dotfile / path)', ''))
            continue
        real = os.path.join(base, name)
        home_path = os.path.join(HOME, name)
        # migrate an existing real directory into Drive, keep the original aside
        if os.path.isdir(home_path) and not os.path.islink(home_path):
            rsync_into(home_path, real)
            aside = home_path + '.pre-drive-link'
            if not os.path.exists(aside):
                os.rename(home_path, aside)
            else:
                rows.append((name, f'copied to Drive, but {aside} already exists; home dir left as-is', ''))
                continue
        os.makedirs(real, exist_ok=True)
        r1 = link(real, home_path)
        r2 = link(real, os.path.join(CONTENT, name)) if LINK_IN_CONTENT else 'skipped'
        rows.append((name, f'~/{name}: {r1}', f'{CONTENT}/{name}: {r2}'))
    for r in rows:
        log(f'{r[0]:14} {r[1]:48} {r[2]}')
    log('done. Verify: ls -l ~ | grep -- "->"   and   touch ~/%s/.probe && ls %s/.probe' % (LINKS[0], os.path.join(base, LINKS[0])))


if __name__ == '__main__':
    main()
