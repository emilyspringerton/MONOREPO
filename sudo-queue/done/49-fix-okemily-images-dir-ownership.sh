#!/bin/bash
# Fixes /var/www/okemily/images/ ownership so okemily-deploy.sh (run as fatbaby, no sudo) can
# actually write to it. Found live deploying kanban EMILY-LOGO-1234 ("/design update the emily
# okemily main site with this art"): rsync failed with "mkstemp ... Permission denied" -- the
# directory is owned by a DIFFERENT local user (treeiii:treeiii, mode 775), unlike the rest of
# /var/www/okemily/ which is already fatbaby:www-data mode 2775 (see OKEMILY/CLAUDE.md's own
# "Deploy" section) precisely so deploys never need sudo. Two existing images in there
# (wotan-fenrir.jpg, wotan-viking-warrior.jpg) were apparently uploaded as treeiii at some
# earlier point and never had their ownership reconciled.
set -e

echo "Fixing ownership of /var/www/okemily/images/..."
chown -R fatbaby:www-data /var/www/okemily/images
chmod -R 2775 /var/www/okemily/images

echo "Done. Verifying..."
ls -la /var/www/okemily/images/
