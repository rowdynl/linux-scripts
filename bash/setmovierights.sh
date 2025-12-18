clear
echo "Processing Series..."
chown -R rowdy:users /volume1/series
chmod -R 0777 /volume1/series
echo "Processing movies..."
chown -R rowdy:users /volume1/movies
chmod -R 0777 /volume1/movies
echo "Done =)"
