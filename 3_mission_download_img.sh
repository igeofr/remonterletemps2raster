#!/bin/bash

# LECTURE DU FICHIER DE CONFIGURATION
. './config.env'

# REPERTOIRE DE TRAVAIL
cd $REPER
echo $REPER

folder_mission=$REPER'/2_mission/'$id_mission

rm $folder_mission'/couverture_bbox/captures.'*
rm $folder_mission'/couverture_bbox/captures_join.'*

for h in $folder_mission'/kml/'*'.kml'
do
  # EXTRACTION DU NOM DE FICHIER
  h1="${h%%.*}"
  mission_part="${h1##*/}"
  echo '################################################################'
  echo 'Nom du fichier kml : ' $mission_part

  if [ "$(uname)" == "Darwin" ]; then
   sed -i '' "s/<value\/>/<value><\/value>/g" $h
 elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
   sed -i "s/<value\/>/<value><\/value>/g" $h
 fi


  # PERMET L'EXTRACTION DES ATTRIBUTS DE CHACUNE DES IMG
  awk -F"[><]" '/<\/Data>/{a="";next} /<Data>/{a=1;next} a && /<value>/{print $3}' $folder_mission'/kml/'${h##*/} > $folder_mission'/csv_attributs/'$mission_part'_value.csv'
  awk -F"[><]" '/<\/Data>/{a="";next} /<Data>/{a=1;next} a && /<displayName>/{print $3}' $folder_mission'/kml/'${h##*/} > $folder_mission'/csv_attributs/'$mission_part'_displayName.csv'

  if [ "$(uname)" == "Darwin" ]; then
    sed -i '' "s/ //g" $folder_mission'/csv_attributs/'$mission_part'_value.csv' > $folder_mission'/csv_attributs/'$mission_part'_value_origin.csv'
    sed -i '' "s/ //g" $folder_mission'/csv_attributs/'$mission_part'_displayName.csv' > $folder_mission'/csv_attributs/'$mission_part'_displayName_origin.csv'

  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
   sed "s/ //g" $folder_mission'/csv_attributs/'$mission_part'_value.csv' > $folder_mission'/csv_attributs/'$mission_part'_value_origin.csv'
   sed "s/ //g" $folder_mission'/csv_attributs/'$mission_part'_displayName.csv' > $folder_mission'/csv_attributs/'$mission_part'_displayName_origin.csv'

 fi

 

 count=$(awk '/id/{++n; if (n==2) { print NR; exit}}' $folder_mission'/csv_attributs/'$mission_part'_displayName.csv')
 number=`expr $count - 1`
 echo $number

  # PASSAGE DE LIGNES EN COLONNES
  count=1
  while read line; do
    output=`echo $line | sed "s/id;//" | sed "s/name;//" | sed "s/NUMCLI;//" | sed "s/IDCLICHE;//" | sed "s/RES;//" | sed "s/ORIENTATION;//" | sed "s/DATE;//" | sed "s/IDTA;//" | sed "s/SUPPORT;//" | sed "s/JP2;//" | sed "s/IDMISS;//" | sed "s/PRFXCLI;//" | sed "s/SUFXCLI;//" | sed "s/X;//" | sed "s/Y;//" | sed "s/TYPE;//" | sed "s/RES;//" | sed "s/HEURE;//"`
    echo -n $output
    if [ $count -lt $number ]; then
      echo -n ","
      let "count++"
    else
      echo
      count=1
    fi
  done < $folder_mission'/csv_attributs/'$mission_part'_value.csv' > $folder_mission'/csv_attributs/'$mission_part'_value_transpose.csv'

  ########################
  count=1
  while read line; do
    output=`echo $line `
    echo -n $output
    if [ $count -lt $number ]; then
      echo -n ","
      let "count++"
    else
      echo
      count=1
    fi
  done < $folder_mission'/csv_attributs/'$mission_part'_displayName.csv' > $folder_mission'/csv_attributs/'$mission_part'_displayName_transpose.csv'

  # EXTRACTION DES NOMS DE CHAMPS (PREMIERE LIGNE)
  line=$(head -n 1 $folder_mission'/csv_attributs/'$mission_part'_displayName_transpose.csv')

  # AJOUTE LES NOMS DE CHAMPS

  if [ "$(uname)" == "Darwin" ]; then
   sed -i '' "1i\\
   $line
   " $folder_mission'/csv_attributs/'$mission_part'_value_transpose.csv'
 elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  sed -i 1i"$line" $folder_mission'/csv_attributs/'$mission_part'_value_transpose.csv'
fi






  # IDENTIFICATION DES PRISES DE VUE DE LA MISSION QUI SE TROUVENT DANS LA BBOX
  file=$folder_mission'/couverture_bbox/captures.shp'
  if [ -f "$file" ]
  then
    echo "merge ${h%%.*}.shp"
    ogr2ogr \
    -f 'ESRI Shapefile' \
    -clipdst $bbox_ogr \
    -append \
    $file \
    $folder_mission'/kml/'${h##*/} \
    -nlt POLYGON
  else
    echo "creating merge ${h%%.*}.shp"
    ogr2ogr \
    -f 'ESRI Shapefile' \
    -clipdst $bbox_ogr \
    $file \
    $folder_mission'/kml/'${h##*/} \
    -nlt POLYGON
  fi

  # LISTE DES PRISES DE VUE AU FORMAT CSV
  ogr2ogr -f CSV $folder_mission'/couverture_bbox/captures.csv' $folder_mission'/couverture_bbox/captures.shp' -sql "SELECT Name FROM captures"

  # TROUVE LE NUMERO DE LA COLONNE JP2
  cut -d, -f2- $folder_mission'/csv_attributs/'$mission_part'_value_transpose.csv' > $folder_mission'/csv_attributs/'$mission_part'_value_transpose_noid.csv'
  loc_col_cap=$( awk '
    BEGIN{
      FS=","
    }
    { 
      gsub(/\r/,"")
      for(i=1;i<=NF;i++){
       if($i=="JP2"){
        print i
        exit
      }
    }
  }
  ' $folder_mission'/csv_attributs/'$mission_part'_value_transpose_noid.csv')

  echo $loc_col_cap

  # JOINTURE ENTRE LES DEUX FICHIERS
  awk -F, 'FNR==NR{a[$1]=$'$loc_col_cap';next} $1 in a{$2=a[$1]} 1' OFS=',' $folder_mission'/csv_attributs/'$mission_part'_value_transpose_noid.csv' $folder_mission'/couverture_bbox/captures.csv' > $folder_mission'/csv_liste_img/liste_img.csv'

  # PERMET DE MODIFIER L'ENTETE
  if [ "$(uname)" == "Darwin" ]; then
    sed -i '' '1s/.*/Name,jp2/' $folder_mission'/csv_liste_img/liste_img.csv'
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    sed -i '1s/.*/Name,jp2/' $folder_mission'/csv_liste_img/liste_img.csv'
  fi

  # PERMET D'EXTRAIRE LE NUMERO DE LA COLONNE
  loc_col_a=$( awk '
    BEGIN{
      FS=","
    }
    {
      gsub(/\r/,"")
      for(i=1;i<=NF;i++){
       if($i=="jp2"){
        print i
        exit
      }
    }
  }
  ' $folder_mission'/csv_liste_img/liste_img.csv')

  if [ "$(uname)" == "Darwin" ]; then
    while IFS="," read -r Name ; do
      echo ">>>>>>>" $Name
      echo "URL de téléchargement : https://wxs.ign.fr/$key/jp2/DEMAT.PVA/$id_mission/$Name.jp2"
      curl "https://wxs.ign.fr/$key/jp2/DEMAT.PVA/$id_mission/$Name.jp2" > $folder_mission'/img_jp2/'$Name'.jp2'
      gdal_translate -of JPEG $folder_mission'/img_jp2/'$Name'.jp2' $folder_mission'/img_jpg/'$Name'.jpg';
    done < <(cut -d "," -f${loc_col_a} -s $folder_mission'/csv_liste_img/liste_img.csv' | awk '{if (NR!=1) {print}}')
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    while IFS="," read -r Name ; do
      echo ">>>>>>>" $Name
      echo "URL de téléchargement : https://wxs.ign.fr/$key/jp2/DEMAT.PVA/$id_mission/$Name.jp2"
      curl "https://wxs.ign.fr/$key/jp2/DEMAT.PVA/$id_mission/$Name.jp2" > $folder_mission'/img_jp2/'$Name'.jp2'
      gdal_translate -of JPEG $folder_mission'/img_jp2/'$Name'.jp2' $folder_mission'/img_jpg/'$Name'.jpg';
    done < <(cut -d "," -f${loc_col_a} $folder_mission'/csv_liste_img/liste_img.csv' | awk '{if (NR!=1) {print}}')
  fi


 #JOINTURE ENTRE LE CSV ET LE SHAPEFILE POUR RECUPERER LES VALEURS DU CSV
 mv $folder_mission'/csv_attributs/'$mission_part'_value_transpose.csv' $folder_mission'/liste.csv'

 file_pv=$folder_mission'/couverture_bbox/captures_join.shp'
 if [ -f "$file" ]
 then
  echo "merge ${h%%.*}.shp"
  ogr2ogr \
  -append \
  -f "ESRI Shapefile" \
  -sql "SELECT liste.name AS name,liste.NUMCLI AS numcli, liste.IDCLICHE AS idcliche, liste.RES AS res, liste.ORIENTATION AS orientation, liste.DATE AS date, liste.JP2 AS img   FROM captures LEFT JOIN '$folder_mission/liste.csv'.liste ON captures.Name = liste.name" \
  $file_pv \
  $file \
  -nlt POLYGON
else
  echo "creating merge ${h%%.*}.shp"
  ogr2ogr \
  -f "ESRI Shapefile" \
  -sql "SELECT liste.name AS name,liste.NUMCLI AS numcli, liste.IDCLICHE AS idcliche, liste.RES AS res, liste.ORIENTATION AS orientation, liste.DATE AS date, liste.JP2 AS img   FROM captures LEFT JOIN '$folder_mission/liste.csv'.liste ON captures.Name = liste.name" \
  $file_pv \
  $file \
  -nlt POLYGON
fi

mv $folder_mission'/liste.csv' $folder_mission'/csv_attributs/'$mission_part'_value_transpose.csv'

done

ogr2ogr -f CSV $folder_mission'/csv_exif/list_exif.csv' $folder_mission'/couverture_bbox/captures_join.shp' -dialect sqlite -sql "SELECT '"$folder_mission'/img_jpg/'"'||img||'"'.jpg'"' as SourceFile, y(Centroid(geometry)) as GPSLatitude, x(Centroid(geometry)) as GPSLongitude, replace(date,'-',':')||' 00:00:00' AS DateTimeOriginal FROM captures_join"

exiftool -csv=$folder_mission'/csv_exif/list_exif.csv' $folder_mission'/img_jpg' -Overwrite_Original -m
