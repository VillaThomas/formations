#!/bin/bash

COURS_DIR=cours
IMG_DIR=images
LIST=cours.list

TITLE=""
DATE=""

function build-html {
  mkdir -p output-html/revealjs/css/theme
  mkdir -p output-html/images

  cp $COURS_DIR/styles/"$THEME".css output-html/revealjs/css/theme/"$THEME".css
  cp -r images/* output-html/images/

  while IFS=$ read cours titre modules; do
    for module in $modules; do
      cat $COURS_DIR/$module >> $COURS_DIR/slide-$cours
    done
    TITLE=$titre

    # Header2 are only usefull for beamer, they need to be replaced with Header3 for revealjs interpretation
    sed 's/^## /### /' $COURS_DIR/slide-$cours > tmp_slide-$cours
    mv tmp_slide-$cours $COURS_DIR/slide-$cours
    echo "Build $TITLE"
    docker run -v $PWD:/formations osones/revealjs-builder:stable --standalone --template=/formations/templates/template.revealjs --slide-level 3 -V theme=$THEME -V navigation=frame -V revealjs-url=$REVEALJSURL -V slideNumber=true -V title="$TITLE" -V institute=Osones -o /formations/output-html/"$cours".html /formations/$COURS_DIR/slide-$cours
    rm -f $COURS_DIR/slide-$cours
  done < $LIST
}
function build-pdf {
  mkdir -p output-pdf
#  if [[ $3 != "" ]]; then
#      COURSE=$3
#      grep $COURSE $LIST > cours.list.tmp
#      LIST=cours.list.tmp
#  fi
  for cours in $(cut -d$ -f1 $LIST); do
    docker run -v $PWD/output-pdf:/output -v $PWD/output-html/"$cours".html:/index.html -v $PWD/images:/images osones/wkhtmltopdf:stable -O landscape -s A5 -T 0 file:///index.html\?print-pdf /output/"$cours".pdf
  done
}

display_help() {
    cat <<EOF
USAGE : $0 options

-o output           Type of output you desire (html or pdf), if not specified all outputs are built
-t theme            Theme to use
-u revealjsURL      RevealJS URL that need to be use. If you build formation supports on local environment
                    you should use "." and git clone http://github.com/hakimel/reveal.js and put your index.html into the repository clone.
                    This option is also necessary even if you only want PDF output
-c course           Course to build, if not specified all courses are built

EOF

exit 0

}

while getopts ":o:t:u:c:h" OPT; do
    case $OPT in
        h) display_help ;;
        c) COURSE="$OPTARG";;
        o) OUTPUT="$OPTARG";;
        t) THEME="$OPTARG";;
        u) REVEALJSURL="$OPTARG";;
        ?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

[[ $REVEALJSURL == "" ]] &&  REVEALJSURL="http://formations.osones.com/revealjs"
if [[ $THEME == "" ]]; then
  THEME="osones"
else
  ls $COURS_DIR/styles/"$THEME".css 2> /dev/null
  [ $? -eq 2 ] && echo "Theme $THEME doesn't exist" && exit 1
fi

if [[ $COURSE != "" ]]; then
  grep $COURSE $LIST > cours.list.tmp
  [ $? -eq 1 ] && echo "Course $COURSE doesn't exist, please refer to cours.list" && exit 1
  LIST=cours.list.tmp
fi

if [[ ! $OUTPUT =~ html|pdf|all ]]; then
    echo "Invalid option: either html, pdf or all" >&2
    display_help
    exit 1
elif [[ $OUTPUT == "html" ]]; then
    build-html $REVEALJSURL $THEME $COURSE
elif [[ $OUTPUT == "pdf" || $OUTPUT == "all" ]]; then
    build-html $REVEALJSURL $THEME $COURSE
    build-pdf
fi
rm -f cours.list.tmp