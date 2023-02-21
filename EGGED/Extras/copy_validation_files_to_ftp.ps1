
$YEAR = Get-Date -Format yyyy
$MONTH = Get-Date -Format MM

if ($MONTH -eq '01') {
    $PAST_MONTH = 12
    $PAST_YEAR = $YEAR - 1
}
else {
    $PAST_MONTH = $MONTH - 1
    $PAST_YEAR = $YEAR
}

$SEARCH_DIR = "\\safe01\Google_Buckets\mot-prod-oprout-003\reports\"

$DIR_TEST = Get-ChildItem $SEARCH_DIR | Select-String -Pattern "$PAST_YEAR$PAST_MONTH"

if ($DIR_TEST) {
    $CHILD_DIRS = Get-ChildItem $SEARCH_DIR$DIR_TEST\cpa\

    foreach ($dir in $CHILD_DIRS) {
        "$dir"
        $SRC = "$SEARCH_DIR$DIR_TEST\cpa\$dir\validations.csv"
        $DST = "\\safe01\FTP\Google_Buckets\mot-prod-oprout-003\"
        $new_name = "$YEAR$MONTH-$dir-validations.csv"
        Copy-Item -Path $SRC -Destination (Join-Path $DST $new_name)
    }    
}
else {
    "Missing Past Month Directory - $PAST_YEAR$PAST_MONTH"
    exit 2
}
