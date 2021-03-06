#!/opt/local/bin/perl
##!/proj/axaf/bin/perl -w

# dumps_mon  aka  config_mon
# This program is called whenever new telemetry dumps 
#  are found in /dsops/GOT/input  (currently done by /Dumps/filters
#  Input is dumps_mon.pl -c<ccdm> -p<pcad>
#   where ccdm is acorn output containing TSCPOS, FAPOS and gratings data
#         pcad is acorn output containing quaternion data
#  This program compares this input with expected MP values.
#  Expected values come from pred_state.rdb,
#        see HEAD://proj/gads6/ops/Chex
#  If descrepencies are found, e-mail is sent to sot_yellow_alert

#use Chex;
# 02/09/01 BS Chex_tst allows 0=360 for ra and roll
#use Chex_tst;
use Chex;
# 10/25/01 BS change alerts to sot_yellow, but only send once
#             delete ./.dumps_mon_lock to rearm
# 04/12/02 BS added alerts on Reaction Wheel speeds < $spdlim
# 06/26/02 BS added alerts on ACIS temps
# 04/03/03 BS added IRU current alert
# 04/25/03 BS added ACIS DEA HK TEMP alerts
# 05/07/03 BS added Dither alerts
# 06/26/03 BS change IRU alert to 2-hour mode calculation
#use Statistics::Descriptive::Discrete;
use Discrete;
# 12/16/03 BS add alert for tephin (in iru files, for convenience)
# 12/19/03 BS add alert for HKP27V (in iru files, for convenience)
# 03/29/04 BS send HKP27V to sot_yellow_alert, resend TEPHIN if > 102 F
# 06/03/04 BS added ephin 5EHSE300
# 02/10/05 BS added PLINE04

# ************** Program Parameters ***************************

#  allowable lag time for moves (seconds) # obsolete in v2.0
#$tsclagtime = 500;
#$falagtime = 200;
#$gratlagtime = 1000;
#$qtlagtime = 2000;

#  added 11/28 BS allowable recover time
#   do not report violations that exhibit recovery within rectime seconds
$rectime = 340;

#  violation limits
$tscposlim = 5;  # steps
$faposlim = 5;   # steps
$ralim = 0.05;   # degrees
#$ralim = 0.000001;   # degrees #debug
$declim = 0.05;  # degrees
$rolllim = 0.05; # degrees

$spdlim = 52.4;  # reaction speed alert limt rad/sec
$tratlim = 45 ;  # 3TRMTRAT (SIM temp) limit
#$spdlim = 205;  # test reaction speed alert limt rad/sec

#  gratings parameters # inactive
#$gratinpar = 20;  # position where gratings is considered inserted
#$gratoutpar = 65;  # position where gratings is considered retracted
$gratlim = 10;    # allowable disagreement between A and B readings

# iru limits
$airu1g1i_lim=200;
$tephin_lim=99.00;  # 99F
$eph27v_lim=26.0;  # alert below 26V
$ebox_lim=40.0; # ephin ebox 40C

# pline temp limits
$pline04_lim=42.5;  #lower limit F

#  predicted state file
#$pred_file = "/home/brad/Dumps/Dumps_mon/pred_state.txt";

#  output file (temporary file, if non empty will be e-mailed)
$outfile = "dumps_mon.out";
$aoutfile = "dumps_mon_acis.out"; #temp out for acis violations
$ioutfile = "dumps_mon_iru.out"; #temp out for iru violations
$eoutfile = "dumps_mon_eph.out"; #temp out for eph temp violations
$evoutfile = "dumps_mon_ephv.out"; #temp out for eph voltage violations
$doutfile = "dumps_mon_dea.out"; #temp out for dea violations
$poutfile = "dumps_mon_pline.out"; #temp out for pline violations

#  hack to get name of dump file(s) processed
$dumpname = "/data/mta/Script/Dumps/Dumps_mon/IN/xtmpnew";
# ************** End Program Parameters ***************************
 
#  get most recent predicted state file from HEAD network
#   must have .netrc in home directory
#system "source pred_state.get";

# *****************************************************************
$verbose = 0;

# Parse input arguments
&parse_args;

if ($verbose >= 2) {
    print "$0 args:\n";
    print "\tccdm infile:\t\t$cinfile\n";
    print "\tpcad infile:\t\t$pinfile\n";
    print "\tverbose:\t\t$verbose\n";
}  

my @ccdmfiles;
my @pcadfiles;
my @acisfiles;
my @irufiles;
my @deatfiles;
my @mupsfiles;
my $pcadfile;
my $ccdmfile;
my $acisfile;
my $irufile;
my $deatfile;
my $mupsfile;
my $counter;

my @timearr; #ccdm times
my @qttimearr; #pcad times
my @atimearr; #acis times
my @itimearr; #iru times
my @dttimearr; #dea temp times
my @mtimearr; #mups temp times
my @tscposarr;
my @faposarr;
my @tratarr;
my @grathaarr;
my @grathbarr;
my @gratlaarr;
my @gratlbarr;
my @pmodarr; # for rwheel checks
my @aseqarr; # for rwheel checks
my @spd1arr;
my @spd2arr;
my @spd3arr;
my @spd4arr;
my @spd5arr;
my @spd6arr;
my @raarr;
my @decarr;
my @rollarr;
my @ditharr;
my @apinarr; #acis 1PIN1AT
my @apdaarr; #acis 1PDEAAT
my @apdbarr; #acis 1PDEABT
my @adpyarr; #acis 1DPAMYT
my @adpzarr; #acis 1DPAMZT
my @adezarr; #acis 1DEAMZT
my @cbat;
my @cbbt;
my @crat;
my @crbt;
my @dactat;
my @dactbt;
my @dahacu;
my @dahat;
my @dahavo;
my @dahbcu;
my @dahbt;
my @dahbvo;
my @dahhavo;
my @dahhbvo;
my @de28avo;
my @de28bvo;
my @deamzt;
my @deicacu;
my @deicbcu;
my @den0avo;
my @den0bvo;
my @den1avo;
my @den1bvo;
my @dep0avo;
my @dep0bvo;
my @dep1avo;
my @dep1bvo;
my @dep2avo;
my @dep2bvo;
my @dep3avo;
my @dep3bvo;
my @dp28avo;
my @dp28bvo;
my @dpamyt;
my @dpamzt;
my @dpicacu;
my @dpicbcu;
my @dpp0avo;
my @dpp0bvo;
my @mahcat;
my @mahcbt;
my @mahoat;
my @mahobt;
my @oahat;
my @oahbt;
my @pdeaat;
my @pdeabt;
my @pin1at;
my @ssmyt;
my @sspyt;
my @vahcat;
my @vahcbt;
my @vahoat;
my @vahobt;
my @wrat;
my @wrbt;
my @deatemp1 ; # acis dea temps
my @deatemp2 ; # acis dea temps
my @deatemp3 ; # acis dea temps
my @deatemp4 ; # acis dea temps
my @deatemp5 ; # acis dea temps
my @deatemp6 ; # acis dea temps
my @deatemp7 ; # acis dea temps
my @deatemp8 ; # acis dea temps
my @deatemp9 ; # acis dea temps
my @deatemp10 ; # acis dea temps
my @deatemp11 ; # acis dea temps
my @deatemp12 ; # acis dea temps
my @airu1g1iarr; #iru A g1 current
my @tephinarr; #TEPHIN
my @eph27varr; # ephin 27v V & I
my @eph27sarr; #ephin 27v switch
my @eboxarr; #ephin ebox
my @pline04arr; #mups pline04
my @mnframarr; #minor frame number

if ($cinfile =~ /^\@/) {
    $cinfile = substr($cinfile, 1);

    my @patharr = split("/", $cinfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open CFILE, "<$cinfile";
    
    $counter = 0;
    while($ccdmfile = <CFILE>) {
	chomp $ccdmfile;
	#$ccdmfiles[$counter++] = $path . $ccdmfile;
	$ccdmfiles[$counter++] = $ccdmfile;
    }
    close CFILE;
}
else {
    $ccdmfiles[0] = $cinfile;
}

if ($pinfile =~ /^\@/) {
    $pinfile = substr($pinfile, 1);

    my @patharr = split("/", $pinfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open PFILE, "<$pinfile";
    
    $counter = 0;
    while($pcadfile = <PFILE>) {
	chomp $pcadfile;
	#$pcadfiles[$counter++] = $path . $pcadfile;
	$pcadfiles[$counter++] = $pcadfile;
    }
    close PFILE;
}
else {
    $pcadfiles[0] = $pinfile;
}

if ($ainfile =~ /^\@/) {
    $ainfile = substr($ainfile, 1);

    my @patharr = split("/", $ainfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open AFILE, "<$ainfile";
    
    $counter = 0;
    while($acisfile = <AFILE>) {
	chomp $acisfile;
	$acisfiles[$counter++] = $acisfile;
    }
    close AFILE;
}
else {
    $acisfiles[0] = $ainfile;
}

if ($ginfile =~ /^\@/) {
    $ginfile = substr($ginfile, 1);

    my @patharr = split("/", $ginfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open GFILE, "<$ginfile";
    
    $counter = 0;
    while($irufile = <GFILE>) {
	chomp $irufile;
	$irufiles[$counter++] = $irufile;
    }
    close GFILE;
}
else {
    $irufiles[0] = $ginfile;
}

if ($dtinfile =~ /^\@/) {
    $dtinfile = substr($dtinfile, 1);

    my @patharr = split("/", $dtinfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open DTFILE, "<$dtinfile";
    
    $counter = 0;
    while($deatfile = <DTFILE>) {
	chomp $deatfile;
	$deatfiles[$counter++] = $deatfile;
    }
    close DTFILE;
}
else {
    $deatfiles[0] = $dtinfile;
}

if ($mupsfile =~ /^\@/) {
    $mupsfile = substr($mupsfile, 1);

    my @patharr = split("/", $mupsfile);
    my $path = "";
    
    for ($ii = 0; $ii < $#patharr; $ii++) {
	$path .= "/$patharr[$ii]";
    }

    open DTFILE, "<$mupsfile";
    
    $counter = 0;
    while($mupsfile = <DTFILE>) {
	chomp $mupsfile;
	$mupsfiles[$counter++] = $mupsfile;
    }
    close DTFILE;
}
else {
    $mupsfiles[0] = $mupsfile;
}

# *********************************************************
# read dump data
# *********************************************************
# read dump data
my $hdr;
my @hdrline;
my $intimecol = 0;
# CCDM columns
my $in3tscposcol  = 0;
my $in3faposcol  = 0;
my $intratcol  = 0;
my $ingrathacol  = 0;
my $ingrathbcol  = 0;
my $ingratlacol  = 0;
my $ingratlbcol  = 0;
my $inpmodcol = 0;
my $inaseqcol = 0;
my $inspd1col = 0;
my $inspd2col = 0;
my $inspd3col = 0;
my $inspd4col = 0;
my $inspd5col = 0;
my $inspd6col = 0;

my $j = 0; # counter (indexer) for ccdm obs

foreach $file (@ccdmfiles) {

  open CCDMFILE, "$file" or die "can not open $file";

  $hdr = <CCDMFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYCCDM file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $intimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "3TSCPOS") {
      $in3tscposcol = $ii;
    }
    elsif ($hdrline[$ii] eq "3FAPOS") {
      $in3faposcol = $ii;
    }
    elsif ($hdrline[$ii] eq "3TRMTRAT") {
      $intratcol = $ii;
    }
    elsif ($hdrline[$ii] eq "4HPOSARO") {
      $ingrathacol = $ii;
    }
    elsif ($hdrline[$ii] eq "4HPOSBRO") {
      $ingrathbcol = $ii;
    }
    elsif ($hdrline[$ii] eq "4LPOSARO") {
      $ingratlacol = $ii;
    }
    elsif ($hdrline[$ii] eq "4LPOSBRO") {
      $ingratlbcol = $ii;
    }
    elsif ($hdrline[$ii] eq "AOPCADMD") {
      $inpmodcol = $ii;
    }
    elsif ($hdrline[$ii] eq "AOACASEQ") {
      $inaseqcol = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD1") {
      $inspd1col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD2") {
      $inspd2col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD3") {
      $inspd3col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD4") {
      $inspd4col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD5") {
      $inspd5col = $ii;
    }
    elsif ($hdrline[$ii] eq "AORWSPD6") {
      $inspd6col = $ii;
    }

  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <CCDMFILE>;
  # read ccdm data
  while ( defined ($inline = <CCDMFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$intimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $timearr[$j] = join (":", @time);
    #$timearr[$j] = $inarr[$intimecol];
    my @tmptime = split ("::", $timearr[$j]);
    $timearr[$j] = join (":", @tmptime);
    $tscposarr[$j] = $inarr[$in3tscposcol];
    $faposarr[$j] = $inarr[$in3faposcol];
    $tratarr[$j] = $inarr[$intratcol];
    $grathaarr[$j] = $inarr[$ingrathacol];
    $grathbarr[$j] = $inarr[$ingrathbcol];
    $gratlaarr[$j] = $inarr[$ingratlacol];
    $gratlbarr[$j] = $inarr[$ingratlbcol];
    $pmodarr[$j] = $inarr[$inpmodcol];
    $pmodarr[$j] =~ s/\s+//;
    $aseqarr[$j] = $inarr[$inaseqcol];
    $aseqarr[$j] =~ s/\s+//;
    $spd1arr[$j] = $inarr[$inspd1col];
    $spd2arr[$j] = $inarr[$inspd2col];
    $spd3arr[$j] = $inarr[$inspd3col];
    $spd4arr[$j] = $inarr[$inspd4col];
    $spd5arr[$j] = $inarr[$inspd5col];
    $spd6arr[$j] = $inarr[$inspd6col];
    ++$j;
  } # read ccdm data

  close CCDMFILE;
}

my $inqt1col = 0;
my $inqt2col = 0;
my $inqt3col = 0;
my $inqt4col = 0;
my $indithcol = 0;
$intimecol = 0;
$j = 0; # counter (indexer) for pcad obs
foreach $file (@pcadfiles) {

  open PCADFILE, "$file" or die;

  $hdr = <PCADFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYPCAD file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $intimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "AOATTQT1") {
      $inqt1col = $ii;
    }
    elsif ($hdrline[$ii] eq "AOATTQT2") {
      $inqt2col = $ii;
    }
    elsif ($hdrline[$ii] eq "AOATTQT3") {
      $inqt3col = $ii;
    }
    elsif ($hdrline[$ii] eq "AOATTQT4") {
      $inqt4col = $ii;
    }
    elsif ($hdrline[$ii] eq "AODITHEN") {
      $indithcol = $ii;
    }
  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <PCADFILE>;
  # read pcad data
  while ( defined ($inline = <PCADFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$intimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $qttimearr[$j] = join (":", @time);
    #$qttimearr[$j] = $inarr[$intimecol];
    my @tmptime = split ("::", $qttimearr[$j]);
    $qttimearr[$j] = join (":", @tmptime);
    %raddecroll = &quat_to_euler($inarr[$inqt1col],
                                 $inarr[$inqt2col],
                                 $inarr[$inqt3col],
                                 $inarr[$inqt4col]);
    $raarr[$j] = $raddecroll{ra};
    $decarr[$j] = $raddecroll{dec};
    $rollarr[$j] = $raddecroll{roll};
    $ditharr[$j] = $inarr[$indithcol];
    $ditharr[$j] =~ s/ //g; # remove acorn's spaces or chex won't match
    ++$j;
  } # read pcad data

  close PCADFILE;
}

my $pincol = 0;
my $pdacol = 0;
my $pdbcol = 0;
my $dpycol = 0;
my $dpzcol = 0;
my $dezcol = 0;
$intimecol = 0;
my $cbatcol=0;
my $cbbtcol=0;
my $cratcol=0;
my $crbtcol=0;
my $dactatcol=0;
my $dactbtcol=0;
my $dahacucol=0;
my $dahatcol=0;
my $dahavocol=0;
my $dahbcucol=0;
my $dahbtcol=0;
my $dahbvocol=0;
my $dahhavocol=0;
my $dahhbvocol=0;
my $de28avocol=0;
my $de28bvocol=0;
my $deamztcol=0;
my $deicacucol=0;
my $deicbcucol=0;
my $den0avocol=0;
my $den0bvocol=0;
my $den1avocol=0;
my $den1bvocol=0;
my $dep0avocol=0;
my $dep0bvocol=0;
my $dep1avocol=0;
my $dep1bvocol=0;
my $dep2avocol=0;
my $dep2bvocol=0;
my $dep3avocol=0;
my $dep3bvocol=0;
my $dp28avocol=0;
my $dp28bvocol=0;
my $dpamytcol=0;
my $dpamztcol=0;
my $dpicacucol=0;
my $dpicbcucol=0;
my $dpp0avocol=0;
my $dpp0bvocol=0;
my $mahcatcol=0;
my $mahcbtcol=0;
my $mahoatcol=0;
my $mahobtcol=0;
my $oahatcol=0;
my $oahbtcol=0;
my $pdeaatcol=0;
my $pdeabtcol=0;
my $pin1atcol=0;
my $ssmytcol=0;
my $sspytcol=0;
my $vahcatcol=0;
my $vahcbtcol=0;
my $vahoatcol=0;
my $vahobtcol=0;
my $wratcol=0;
my $wrbtcol=0;
$j = 0; # counter (indexer) for acis obs
foreach $file (@acisfiles) {

  open ACISFILE, "$file" or die;

  $hdr = <ACISFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYACIS file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $intimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "1PIN1AT") {
      $pincol = $ii;
    }
    elsif ($hdrline[$ii] eq "1PDEAAT") {
      $pdacol = $ii;
    }
    elsif ($hdrline[$ii] eq "1PDEABT") {
      $pdbcol = $ii;
    }
    elsif ($hdrline[$ii] eq "1DPAMYT") {
      $dpycol = $ii;
    }
    elsif ($hdrline[$ii] eq "1DPAMZT") {
      $dpzcol = $ii;
    }
    elsif ($hdrline[$ii] =~ /^1cbat/i) {
      $cbatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1cbbt/i) {
      $cbbtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1crat/i) {
      $cratcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1crbt/i) {
      $crbtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dactat/i) {
      $dactatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dactbt/i) {
      $dactbtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahacu/i) {
      $dahacucol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahat/i) {
      $dahatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahavo/i) {
      $dahavocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahbcu/i) {
      $dahbcucol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahbt/i) {
      $dahbtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahbvo/i) {
      $dahbvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahhavo/i) {
      $dahhavocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dahhbvo/i) {
      $dahhbvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1de28avo/i) {
      $de28avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1de28bvo/i) {
      $de28bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1deamzt/i) {
      $deamztcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1deicacu/i) {
      $deicacucol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1deicbcu/i) {
      $deicbcucol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1den0avo/i) {
      $den0avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1den0bvo/i) {
      $den0bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1den1avo/i) {
      $den1avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1den1bvo/i) {
      $den1bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep0avo/i) {
      $dep0avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep0bvo/i) {
      $dep0bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep1avo/i) {
      $dep1avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep1bvo/i) {
      $dep1bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep2avo/i) {
      $dep2avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep2bvo/i) {
      $dep2bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep3avo/i) {
      $dep3avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dep3bvo/i) {
      $dep3bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dp28avo/i) {
      $dp28avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dp28bvo/i) {
      $dp28bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dpamyt/i) {
      $dpamytcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dpamzt/i) {
      $dpamztcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dpicacu/i) {
      $dpicacucol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dpicbcu/i) {
      $dpicbcucol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dpp0avo/i) {
      $dpp0avocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1dpp0bvo/i) {
      $dpp0bvocol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1mahcat/i) {
      $mahcatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1mahcbt/i) {
      $mahcbtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1mahoat/i) {
      $mahoatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1mahobt/i) {
      $mahobtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1oahat/i) {
      $oahatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1oahbt/i) {
      $oahbtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1pdeaat/i) {
      $pdeaatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1pdeabt/i) {
      $pdeabtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1pin1at/i) {
      $pin1atcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1ssmyt/i) {
      $ssmytcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1sspyt/i) {
      $sspytcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1vahcat/i) {
      $vahcatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1vahcbt/i) {
      $vahcbtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1vahoat/i) {
      $vahoatcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1vahobt/i) {
      $vahobtcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1wrat/i) {
      $wratcol=$ii;
    }
    elsif ($hdrline[$ii] =~ /^1wrbt/i) {
      $wrbtcol=$ii;
    }
  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <ACISFILE>;
  # read acis data
  while ( defined ($inline = <ACISFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$intimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $atimearr[$j] = join (":", @time);
    #$qttimearr[$j] = $inarr[$intimecol];
    my @tmptime = split ("::", $atimearr[$j]);
    $atimearr[$j] = join (":", @tmptime);
    $apinarr[$j] = $inarr[$pincol];
    $apdaarr[$j] = $inarr[$pdacol];
    $apdbarr[$j] = $inarr[$pdbcol];
    $adpyarr[$j] = $inarr[$dpycol];
    $adpzarr[$j] = $inarr[$dpzcol];
    $adezarr[$j] = $inarr[$dezcol];
    ++$j;
  } # read acis data

  close ACISFILE;
}

my $airu1g1icol = 0;
my $tephincol = 0;
my $eph27vcol = 0;
my $eph27scol = 0;
my $eboxcol = 0;
my $mnframcol = 0;
$intimecol = 0;
$j = 0; # counter (indexer) for acis obs
foreach $file (@irufiles) {

  open IRUFILE, "$file" or die;

  $hdr = <IRUFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYACIS file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $intimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "AIRU1G1I") {
      $airu1g1icol = $ii;
    }
    elsif ($hdrline[$ii] eq "TEPHIN") {
      $tephincol = $ii;
    }
    elsif ($hdrline[$ii] eq "5HSE202") {
      $eph27vcol = $ii;
    }
    elsif ($hdrline[$ii] eq "5EHSE106") {
      $eph27scol = $ii;
    }
    elsif ($hdrline[$ii] eq "5EHSE300") {
      $eboxcol = $ii;
    }
    # also must use minor frame #
    #  don't use first few minor frames
    #  acorn can take several mn frames to change 5HSE202
    elsif ($hdrline[$ii] eq "CVCMNCTR") {
      $mnframcol = $ii;
    }
  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <IRUFILE>;
  # read iru data
  while ( defined ($inline = <IRUFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$intimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $itimearr[$j] = join (":", @time);
    #$qttimearr[$j] = $inarr[$intimecol];
    my @tmptime = split ("::", $itimearr[$j]);
    $itimearr[$j] = join (":", @tmptime);
    $airu1g1iarr[$j] = $inarr[$airu1g1icol];
    $tephinarr[$j] = $inarr[$tephincol];
    $eph27varr[$j] = $inarr[$eph27vcol];
    $eph27sarr[$j] = $inarr[$eph27scol];
    $eboxarr[$j] = $inarr[$eboxcol];
    $mnframarr[$j] = $inarr[$mnframcol];
    ++$j;
  } # read iru data

  close IRUFILE;
}

my $pline04col = 0;
$intimecol = 0;
$j = 0; # counter (indexer) for acis obs
foreach $file (@mupsfiles) {

  open MUPSFILE, "$file" or die;

  $hdr = <MUPSFILE>;
  chomp $hdr;
  # Get column information on the input PRIMARYMUPS2 file
  @hdrline = split ("\t", $hdr);

  for ($ii=0; $ii<=$#hdrline; $ii++) {
    if ($hdrline[$ii] eq "TIME") {
      $mintimecol = $ii;
    }    
    elsif ($hdrline[$ii] eq "PLINE04T") {
      $pline04col = $ii;
    }
  } # for ($ii=0; $ii<=$#hdrline; $ii++)

  my @inarr;
  my $inline;

  # remove whitespace line
  $inline = <MUPSFILE>;
  # read MUPS data
  while ( defined ($inline = <MUPSFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    # fix acorn y2k bug
    my @time = split (" ", $inarr[$mintimecol]);
    if ($time[0] < 1900) {
      $time[0] = $time[0] + 1900;
    }
    $mtimearr[$j] = join (":", @time);
    my @tmptime = split ("::", $mtimearr[$j]);
    $mtimearr[$j] = join (":", @tmptime);
    $pline04arr[$j] = $inarr[$pline04col];
    ++$j;
  } # read iru data

  close MUPSFILE;
}

#  dea hkp temperatures - this one's different than the others
#    since input does not come from acorn
my $dttimecol = 0;
my $deahk1col = 1;
my $deahk2col = 2;
my $deahk3col = 3;
my $deahk4col = 4;
my $deahk5col = 5;
my $deahk6col = 6;
my $deahk7col = 7;
my $deahk8col = 8;
my $deahk9col = 9;
my $deahk10col = 10;
my $deahk11col = 11;
my $deahk12col = 12;
$j = 0; # counter (indexer) for acis obs
foreach $file (@deatfiles) {

  open DEAFILE, "$file" or die;
  my @inarr;
  my $inline;

  # remove whitespace line
  #$inline = <DEAFILE>;
  # read dea data
  while ( defined ($inline = <DEAFILE>)) {
    chomp ($inline);
    @inarr = split ("\t", $inline);
    $dttimearr[$j] = $inarr[$dttimecol];
    $deatemp1[$j] = $inarr[$deahk1col];
    $deatemp2[$j] = $inarr[$deahk2col];
    $deatemp3[$j] = $inarr[$deahk3col];
    $deatemp4[$j] = $inarr[$deahk4col];
    $deatemp5[$j] = $inarr[$deahk5col];
    $deatemp6[$j] = $inarr[$deahk6col];
    $deatemp7[$j] = $inarr[$deahk7col];
    $deatemp8[$j] = $inarr[$deahk8col];
    $deatemp9[$j] = $inarr[$deahk9col];
    $deatemp10[$j] = $inarr[$deahk10col];
    $deatemp11[$j] = $inarr[$deahk11col];
    $deatemp12[$j] = $inarr[$deahk12col];
    ++$j;
  } # read dea data

  close DEAFILE;
}
# *****************************************************************
# **************** Compare actual to predicted ********************
#$chex = Chex->new('/home/brad/Dumps/Dumps_mon/pred_state.rdb');
#$chex = Chex->new('/data/mta/Script/Dumps/Dumps_mon/pred_state.rdb');
$chex = Chex->new('/home/mta/Chex/pred_state.rdb');
# ccdm
open REPORT, "> $outfile";
open DREPORT, "> testfile.out";
my $tscviol = 0;
my $faviol = 0;
my $tratviol = 0;
my $spd1viol = 0;
my $spd2viol = 0;
my $spd3viol = 0;
my $spd4viol = 0;
my $spd5viol = 0;
my $spd6viol = 0;
$j = 0;
for ( $i=0; $i<$#timearr; $i++ ) {
 #print "TSC $i $#timearr\n"; #debugggg
#for ( $i=0; $i<20; $i++ ) { # debug

  ######### check tscpos ########
  $match = $chex->match(var => 'simtsc',
                        val => $tscposarr[$i],
                        tol => $tscposlim,
                        date=> $timearr[$i]);
  if ( $match == 0 && $tscviol == 0) {
    $tscviol = 1;
    $tsctmptime = $timearr[$i];
    $tsctmppos = $tscposarr[$i];
    @tsctmppred = @{$chex->{chex}{simtsc}};
    #printf REPORT " TSC   Violation at %19s Actual: %8.1f Expected: %8.1f\n", $timearr[$i], $tscposarr[$i], @{$chex->{chex}{simtsc}};
  }
  if ( $match == 1 && $tscviol == 1) {
    $tscviol = 0;
    if ( convert_time($timearr[$i]) - convert_time($tsctmptime) > $rectime ) {
      printf REPORT " TSC   Violation at %19s Actual: %8.1f Expected: %8.1f\n", $tsctmptime, $tsctmppos, @tsctmppred;
      @recpos = @{$chex->{chex}{simtsc}};
      $m = &index_match($tscposarr[$i], $tscposlim, @recpos);
      printf REPORT " TSC   Recovery at %19s Actual: %8.1f Expected: %8.1f\n", $timearr[$i], $tscposarr[$i], $recpos[$m];
    }
  }

  ######### check fapos ########
  $match = $chex->match(var => 'simfa',
                        val => $faposarr[$i],
                        tol => $faposlim,
                        date=> $timearr[$i]);
  if ( $match == 0 && $faviol == 0) {
    $faviol = 1;
    $fatmptime = $timearr[$i];
    $fatmppos = $faposarr[$i];
    @fatmppred = @{$chex->{chex}{simfa}};
    #printf REPORT " FA    Violation at %19s Actual: %8.1f Expected: %8.1f\n", $timearr[$i], $faposarr[$i], @{$chex->{chex}{simfa}};
  }
  if ( $match == 1 && $faviol == 1) {
    $faviol = 0;
    if ( convert_time($timearr[$i]) - convert_time($fatmptime) > $rectime ) {
      printf REPORT " FA    Violation at %19s Actual: %8.1f Expected: %8.1f\n", $fatmptime, $fatmppos, @fatmppred;
      @recpos = @{$chex->{chex}{simfa}};
      $m = &index_match($faposarr[$i], $faposlim, @recpos);
      printf REPORT " FA    Recovery at %19s Actual: %8.1f Expected: %8.1f\n", $timearr[$i], $faposarr[$i], $recpos[$m];
    }
  }

  ######## check gratings ########
  if ( abs($grathaarr[$i] - $grathbarr[$i]) > $gratlim ) {
    print REPORT "HETG disagreement $timearr[$i] $grathaarr[$i] $grathbarr[$i]\n";
  }
  if ( abs($gratlaarr[$i] - $gratlbarr[$i]) > $gratlim ) {
    print REPORT "LETG disagreement $timearr[$i] $gratlaarr[$i] $gratlbarr[$i]\n";
  }

  ##if ( $stimearr[$i] - $sbtimearr[$j] > $gratlagtime && $bgratarr[$j] ne "undef") {
    ##if ( $grathaarr[$i] < $gratinpar && $bgratarr[$j] ne "HETG" ) {
      #print report "HETG VIOLATION $timearr[$i] $grathaarr[$i] $btimearr[$j] $bgratarr[$j]\n";
    #}
    #if ( $gratlaarr[$i] < $gratinpar && $bgratarr[$j] ne "LETG" ) {
      #print report "LETG VIOLATION $timearr[$i] $gratlaarr[$i] $btimearr[$j] $bgratarr[$j]\n";
    #}
    #if ( $grathaarr[$i] > $gratinpar && $bgratarr[$j] eq "HETG" ) {
      #print report "HETG VIOLATION $timearr[$i] $grathaarr[$i] $btimearr[$j] $bgratarr[$j]\n";
    #}
    #if ( $gratlaarr[$i] > $gratinpar && $bgratarr[$j] eq "LETG" ) {
      #print report "LETG VIOLATION $timearr[$i] $gratlaarr[$i] $btimearr[$j] $bgratarr[$j]\n";
    #}
    #if ( $grathaarr[$i] < $gratoutpar && $bgratarr[$j] eq "NONE" ) {
      #print report "HETG VIOLATION $timearr[$i] $grathaarr[$i] $btimearr[$j] $bgratarr[$j]\n";
    #}
    #if ( $gratlaarr[$i] < $gratoutpar && $bgratarr[$j] eq "NONE" ) {
      #print report "LETG VIOLATION $timearr[$i] $gratlaarr[$i] $btimearr[$j] $bgratarr[$j]\n";
    #}
  #}

  ######### check SIM temp ########
  if ( ($tratarr[$i]) > $tratlim && $tratviol == 0) {
    $tratviol = 1;
    $trattmptime = $timearr[$i];
    $trattmppos = $tratarr[$i];
  } elsif ( ($tratarr[$i]) < $tratlim && $tratviol == 1) {
    $tratviol = 0;
    if ( convert_time($timearr[$i]) - convert_time($trattmptime) > $rectime ) {
      printf REPORT " 3TRMTRAT    Violation at %19s Actual: %4.1f Expected: \< %4.1f deg C\n", $trattmptime, $trattmppos, $tratlim;
      printf REPORT " 3TRMTRAT    Recovery at %19s Actual: %4.1f Expected: \< %4.1f deg C\n", $timearr[$i], $tratarr[$i], $tratlim;
    }
  }
  ######### check rw speeds ########
  if ( $aseqarr[$i] eq "KALM" && $pmodarr[$i] eq "NPNT") {
    if ( abs($spd1arr[$i]) < $spdlim && $spd1viol == 0) {
      $spd1viol = 1;
      $spd1tmptime = $timearr[$i];
      $spd1tmppos = $spd1arr[$i];
    } elsif ( abs($spd1arr[$i]) > $spdlim && $spd1viol == 1) {
      $spd1viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd1tmptime) > $rectime ) {
        printf REPORT " AORWSPD1    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd1tmptime, $spd1tmppos, $spdlim;
        printf REPORT " AORWSPD1    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd1arr[$i], $spdlim;
      }
    }
    if ( abs($spd2arr[$i]) < $spdlim && $spd2viol == 0) {
      $spd2viol = 1;
      $spd2tmptime = $timearr[$i];
      $spd2tmppos = $spd2arr[$i];
    } elsif ( abs($spd2arr[$i]) > $spdlim && $spd2viol == 1) {
      $spd2viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd2tmptime) > $rectime ) {
        printf REPORT " AORWSPD2    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd2tmptime, $spd2tmppos, $spdlim;
        printf REPORT " AORWSPD2    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd2arr[$i], $spdlim;
      }
    }
    if ( abs($spd3arr[$i]) < $spdlim && $spd3viol == 0) {
      $spd3viol = 1;
      $spd3tmptime = $timearr[$i];
      $spd3tmppos = $spd3arr[$i];
    } elsif ( abs($spd3arr[$i]) > $spdlim && $spd3viol == 1) {
      $spd3viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd3tmptime) > $rectime ) {
        printf REPORT " AORWSPD3    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd3tmptime, $spd3tmppos, $spdlim;
        printf REPORT " AORWSPD3    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd3arr[$i], $spdlim;
      }
    }
    if ( abs($spd4arr[$i]) < $spdlim && $spd4viol == 0) {
      $spd4viol = 1;
      $spd4tmptime = $timearr[$i];
      $spd4tmppos = $spd4arr[$i];
    } elsif ( abs($spd4arr[$i]) > $spdlim && $spd4viol == 1) {
      $spd4viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd4tmptime) > $rectime ) {
        printf REPORT " AORWSPD4    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd4tmptime, $spd4tmppos, $spdlim;
        printf REPORT " AORWSPD4    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd4arr[$i], $spdlim;
      }
    }
    if ( abs($spd5arr[$i]) < $spdlim && $spd5viol == 0) {
      $spd5viol = 1;
      $spd5tmptime = $timearr[$i];
      $spd5tmppos = $spd5arr[$i];
    } elsif ( abs($spd5arr[$i]) > $spdlim && $spd5viol == 1) {
      $spd5viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd5tmptime) > $rectime ) {
        printf REPORT " AORWSPD5    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd5tmptime, $spd5tmppos, $spdlim;
        printf REPORT " AORWSPD5    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd5arr[$i], $spdlim;
      }
    }
    if ( abs($spd6arr[$i]) < $spdlim && $spd6viol == 0) {
      $spd6viol = 1;
      $spd6tmptime = $timearr[$i];
      $spd6tmppos = $spd6arr[$i];
    } elsif ( abs($spd6arr[$i]) > $spdlim && $spd6viol == 1) {
      $spd6viol = 0;
      if ( convert_time($timearr[$i]) - convert_time($spd6tmptime) > $rectime ) {
        printf REPORT " AORWSPD6    Violation at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $spd6tmptime, $spd6tmppos, $spdlim;
        printf REPORT " AORWSPD6    Recovery at %19s Actual: %4.1f Expected: \> %4.1f rad/s\n", $timearr[$i], $spd6arr[$i], $spdlim;
      }
    }
  }
} # for #timearr
# Report violations that do not exhibit recovery
if ( $tscviol == 1 ) {
  printf REPORT " TSC   Violation at %19s Actual: %8.1f Expected: %8.1f\n", $tsctmptime, $tsctmppos, @tsctmppred;
}
if ( $faviol == 1 ) {
  printf REPORT " FA    Violation at %19s Actual: %8.1f Expected: %8.1f\n", $fatmptime, $fatmppos, @fatmppred;
}
if ( $tratviol == 1 ) {
  printf REPORT " 3TRMTRAT    Violation at %19s Actual: %8.1f Expected: \< %8.1f deg C\n", $trattmptime, $trattmppos, $tratlim;
}
if ( $spd1viol == 1 ) {
  printf REPORT " AORWSPD1    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd1tmptime, $spd1tmppos, $spdlim;
}
if ( $spd2viol == 1 ) {
  printf REPORT " AORWSPD2    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd2tmptime, $spd2tmppos, $spdlim;
}
if ( $spd3viol == 1 ) {
  printf REPORT " AORWSPD3    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd3tmptime, $spd3tmppos, $spdlim;
}
if ( $spd4viol == 1 ) {
  printf REPORT " AORWSPD4    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd4tmptime, $spd4tmppos, $spdlim;
}
if ( $spd5viol == 1 ) {
  printf REPORT " AORWSPD5    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd5tmptime, $spd5tmppos, $spdlim;
}
if ( $spd6viol == 1 ) {
  printf REPORT " AORWSPD6    Violation at %19s Actual: %8.1f Expected: \> %4.1f rad/s\n", $spd6tmptime, $spd6tmppos, $spdlim;
}

# ******************************************************************

# pcad comparisons
#  separate loop because different times
my $raviol = 0;
my $decviol = 0;
my $rollviol = 0;
my $dithviol = 0;
$j = 0;
#open PTEST, ">>pcadtest.out"; # debugpcad
for ( $i=0; $i<$#qttimearr; $i++ ) {
 #print "PCAD $i $#qttimearr\n"; #debugggg
#for ( $i=0; $i<20; $i++ ) { # debug
  #printf PTEST "$qttimearr[$i] $raarr[$i] $decarr[$i] $rollarr[$i]\n"; #debugpcad

  ######## check ra ########
  $match = $chex->match(var => 'ra',
                        val => $raarr[$i],
                        tol => $ralim,
                        date=> $qttimearr[$i]);
  if ( $match == 0 && $raviol == 0) {
    # double check if 0/360
    $raviol = 1;
    $ratmptime = $qttimearr[$i];
    $ratmppos = $raarr[$i];
    @ratmppred = @{$chex->{chex}{ra}};
    #printf REPORT " RA    Violation at %19s Actual: %8.4f Expected: %8.4f\n", $qttimearr[$i], $raarr[$i], @{$chex->{chex}{ra}};
  }
  if ( $match == 1 && $raviol == 1) {
    $raviol = 0;
    if ( convert_time($qttimearr[$i]) - convert_time($ratmptime) > $rectime ) {
      printf REPORT " RA    Violation at %19s Actual: %8.4f Expected: %8.4f\n", $ratmptime, $ratmppos, @ratmppred;
      @recpos = @{$chex->{chex}{ra}};
      $m = &index_match($raarr[$i], $ralim, @recpos);
      printf REPORT " RA    Recovery at %19s Actual: %8.4f Expected: %8.4f\n", $qttimearr[$i], $raarr[$i], $recpos[$m];
    }
  }

  ######## check dec ########
  $match = $chex->match(var => 'dec',
                        val => $decarr[$i],
                        tol => $declim,
                        date=> $qttimearr[$i]);
  if ( $match == 0 && $decviol == 0) {
    $decviol = 1;
    $dectmptime = $qttimearr[$i];
    $dectmppos = $decarr[$i];
    @dectmppred = @{$chex->{chex}{dec}};
    #printf REPORT " DEC   Violation at %19s Actual: %8.4f Expected: %8.4f\n", $qttimearr[$i], $decarr[$i], @{$chex->{chex}{dec}};
  }
  if ( $match == 1 && $decviol == 1) {
    $decviol = 0;
    if ( convert_time($qttimearr[$i]) - convert_time($dectmptime) > $rectime ) {
      printf REPORT " DEC   Violation at %19s Actual: %8.4f Expected: %8.4f\n", $dectmptime, $dectmppos, @dectmppred;
      @recpos = @{$chex->{chex}{dec}};
      $m = &index_match($decarr[$i], $declim, @recpos, 25);
      printf REPORT " DEC   Recovery at %19s Actual: %8.4f Expected: %8.4f\n", $qttimearr[$i], $decarr[$i], $recpos[$m];
    }
  }

  ######## check roll ########
  $match = $chex->match(var => 'roll',
                        val => $rollarr[$i],
                        tol => $rolllim,
                        date=> $qttimearr[$i]);
  if ( $match == 0 && $rollviol == 0) {
    $rollviol = 1;
    $rolltmptime = $qttimearr[$i];
    $rolltmppos = $rollarr[$i];
    @rolltmppred = @{$chex->{chex}{roll}};
    #printf REPORT " ROLL  Violation at %19s Actual: %8.4f Expected: %8.4f\n", $qttimearr[$i], $rollarr[$i], @{$chex->{chex}{roll}};
  }
  if ( $match == 1 && $rollviol == 1) {
    $rollviol = 0;
    if ( convert_time($qttimearr[$i]) - convert_time($rolltmptime) > $rectime ) {
      printf REPORT " ROLL  Violation at %19s Actual: %8.4f Expected: %8.4f\n", $rolltmptime, $rolltmppos, @rolltmppred;
      @recpos = @{$chex->{chex}{roll}};
      $m = &index_match($rollarr[$i], $rolllim, @recpos);
      printf REPORT " ROLL  Recovery at %19s Actual: %8.4f Expected: %8.4f\n", $qttimearr[$i], $rollarr[$i], $recpos[$m];
    }
  }

  ######## check dither ########
#dither_check  $match = $chex->match(var => 'dither',
#dither_check                        val => $ditharr[$i],
#dither_check                        tol => 'MATCH',
#dither_check                        date=> $qttimearr[$i]);
#dither_check  if ( $match == 0 && $dithviol == 0) {
#dither_check    $dithviol = 1;
#dither_check    $dithtmptime = $qttimearr[$i];
#dither_check    $dithtmppos = $ditharr[$i];
#dither_check    @dithtmppred = @{$chex->{chex}{dither}};
#dither_check  }
#dither_check  if ( $match == 1 && $dithviol == 1) {
#dither_check    $dithviol = 0;
#dither_check    if ( convert_time($qttimearr[$i]) - convert_time($dithtmptime) > $rectime ) {
#dither_check      printf DREPORT " DITHER  Violation at %19s Actual: %5s Expected: %5s\n", $dithtmptime, $dithtmppos, @dithtmppred;
#dither_check      @recpos = @{$chex->{chex}{dither}};
#dither_check      $m = &index_match($ditharr[$i], 0, @recpos);
#dither_check      printf DREPORT " DITHER  Recovery at %19s Actual: %5s Expected: %5s\n", $qttimearr[$i], $ditharr[$i], $recpos[$m];
#dither_check    }
#dither_check  }

} # for #qttimearr
# Report violations that do not exhibit recovery
if ( $raviol == 1 ) {
      printf REPORT " RA    Violation at %19s Actual: %8.4f Expected: %8.4f\n", $ratmptime, $ratmppos, @ratmppred;
}
if ( $decviol == 1 ) {
      printf REPORT " DEC   Violation at %19s Actual: %8.4f Expected: %8.4f\n", $dectmptime, $dectmppos, @dectmppred;
}
if ( $rollviol == 1 ) {
      printf REPORT " ROLL  Violation at %19s Actual: %8.4f Expected: %8.4f\n", $rolltmptime, $rolltmppos, @rolltmppred;
}
#dither_checkif ( $dithviol == 1 ) {
#dither_check      printf DREPORT " DITHER  Violation at %19s Actual: %5s Expected: %5s\n", $dithtmptime, $dithtmppos, @dithtmppred;
#dither_check}

#close PTEST; #debugpcad
close REPORT;
close DREPORT;

# ******************************************************************
# acis checks
my $pinviol = 0;
my $pdaviol = 0;
my $pdbviol = 0;
my $dpyviol = 0;
my $dpzviol = 0;
my $dezviol = 0;
# ****** acis temp limits degC
my $apinmin = -5.0; #1PIN1AT		PSMC Temp 1A
my $apinmax = 41.0;
my $hsapinmin = -20.0; #1PIN1AT	Health and Safety limits
my $hsapinmax = 46.0;
#$apinmax = 12.0; # test
my $apdamin = 0.0 ; #1PDEAAT		PSMC DEA Power Supply Temp A
my $apdamax = 57.0;
my $hsapdamin = -10.0 ; #1PDEAAT		PSMC DEA Power Supply Temp A
my $hsapdamax = 62.0;
#$apdamin = 28.0 ; # test
my $apdbmin = 0.0 ; #1PDEABT		PSMC DEA Power Supply Temp B
my $apdbmax = 57.0;
my $hsapdbmin = -10.0 ; #1PDEABT		PSMC DEA Power Supply Temp B
my $hsapdbmax = 62.0;
#$apdbmax = 10.0;# test
my $adpymin = 1.0 ; #1DPAMYT		DPA -Y Panel Temp (RT810)
my $adpymax = 20.0;
my $hsadpymin = -20.0 ; #1DPAMYT		DPA -Y Panel Temp (RT810)
my $hsadpymax = 40.5;
#$adpymax = 10.0;# test
my $adpzmin = 4.0 ; #1DPAMZT		DPA -Z Panel Temp (RT830)
my $adpzmax = 20.0;
my $hsadpzmin = -20.0 ; #1DPAMZT		DPA -Z Panel Temp (RT830)
my $hsadpzmax = 40.5;
#$adpzmin = 14.0 ; # test
my $adezmin = 4.0 ; #1DEAMZT 	DEA -Z Panel Temp (RT830)
my $adezmax = 12.0;
my $hsadezmin = -20.0 ; #1DEAMZT 	DEA -Z Panel Temp (RT830)
my $hsadezmax = 20.0;
#$adezmin = 11.0 ; # test

$j = 0;
open REPORT, "> $aoutfile";
for ( $i=0; $i<$#atimearr; $i++ ) {
 #print "ACIS $i $#atimearr\n"; #debugggg

  if ( $apinarr[$i] != 0 && ($apinarr[$i] <= $apinmin || $apinarr[$i] >= $apinmax) && $pinviol == 0) {
    $pinviol = 1;
    $pintmptime = $atimearr[$i];
    $pintmppos = $apinarr[$i];
  }
  if ( $apinarr[$i] ne "" && $apinarr[$i] > $apinmin && $apinarr[$i] < $apinmax && $pinviol == 1) {
    $pinviol = 0;
    if ( convert_time($atimearr[$i]) - convert_time($pintmptime) > $rectime ) {
      printf REPORT "1PIN1AT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $pintmptime, $pintmppos, $apinmin, $apinmax, $hsapinmin,$hsapinmax;
      printf REPORT "1PIN1AT  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f\n", $atimearr[$i], $apinarr[$i], $apinmin, $apinmax;
    }
  }

  if ( $apdaarr[$i] ne "" && ($apdaarr[$i] <= $apdamin || $apdaarr[$i] >= $apdamax) && $pdaviol == 0) {
    $pdaviol = 1;
    $pdatmptime = $atimearr[$i];
    $pdatmppos = $apdaarr[$i];
  }
  if ( $apdaarr[$i] ne "" && $apdaarr[$i] > $apdamin && $apdaarr[$i] < $apdamax && $pdaviol == 1) {
    $pdaviol = 0;
    if ( convert_time($atimearr[$i]) - convert_time($pdatmptime) > $rectime ) {
      printf REPORT "1PDEAAT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $pdatmptime, $pdatmppos, $apdamin, $apdamax, $hsapdamin,$hsapdamax;
      printf REPORT "1PDEAAT  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f\n", $atimearr[$i], $apdaarr[$i], $apdamin, $apdamax;
    }
  }

  if ( $apdbarr[$i] ne "" && ($apdbarr[$i] <= $apdbmin || $apdbarr[$i] >= $apdbmax) && $pdbviol == 0) {
    $pdbviol = 1;
    $pdbtmptime = $atimearr[$i];
    $pdbtmppos = $apdbarr[$i];
  }
  if ( $apdbarr[$i] ne "" && $apdbarr[$i] > $apdbmin && $apdbarr[$i] < $apdbmax && $pdbviol == 1) {
    $pdbviol = 0;
    if ( convert_time($atimearr[$i]) - convert_time($pdbtmptime) > $rectime ) {
      printf REPORT "1PDEABT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f\n Health & Safety limits: %7.2f,%7.2f", $pdbtmptime, $pdbtmppos, $apdbmin, $apdbmax,$hsapdbmin,$hsapdbmax;
      printf REPORT "1PDEABT  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f\n", $atimearr[$i], $apdbarr[$i], $apdbmin, $apdbmax;
    }
  }

  if ( $adpyarr[$i] ne "" && ($adpyarr[$i] <= $adpymin || $adpyarr[$i] >= $adpymax) && $dpyviol == 0) {
    $dpyviol = 1;
    $dpytmptime = $atimearr[$i];
    $dpytmppos = $adpyarr[$i];
  }
  if ( $adpyarr[$i] ne "" && $adpyarr[$i] > $adpymin && $adpyarr[$i] < $adpymax && $dpyviol == 1) {
    $dpyviol = 0;
    if ( convert_time($atimearr[$i]) - convert_time($dpytmptime) > $rectime ) {
      printf REPORT "1DPAMYT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $dpytmptime, $dpytmppos, $adpymin, $adpymax,$hsadpymin,$hsadpymax;
      printf REPORT "1DPAMYT  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f\n", $atimearr[$i], $adpyarr[$i], $adpymin, $adpymax;
    }
  }

  if ( $adpzarr[$i] ne "" && ($adpzarr[$i] <= $adpzmin || $adpzarr[$i] >= $adpzmax) && $dpzviol == 0) {
    $dpzviol = 1;
    $dpztmptime = $atimearr[$i];
    $dpztmppos = $adpzarr[$i];
  }
  if ( $adpzarr[$i] ne "" && $adpzarr[$i] > $adpzmin && $adpzarr[$i] < $adpzmax && $dpzviol == 1) {
    $dpzviol = 0;
    if ( convert_time($atimearr[$i]) - convert_time($dpztmptime) > $rectime ) {
      printf REPORT "1DPAMZT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $dpztmptime, $dpztmppos, $adpzmin, $adpzmax,$hsadpzmin,$hsadpzmax;
      printf REPORT "1DPAMZT  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f\n", $atimearr[$i], $adpzarr[$i], $adpzmin, $adpzmax;
    }
  }

  if ( $adezarr[$i] ne "" && ($adezarr[$i] <= $adezmin || $adezarr[$i] >= $adezmax) && $dezviol == 0) {
    $dezviol = 1;
    $deztmptime = $atimearr[$i];
    $deztmppos = $adezarr[$i];
  }
  if ( $adezarr[$i] ne "" && $adezarr[$i] > $adezmin && $adezarr[$i] < $adezmax && $dezviol == 1) {
    $dezviol = 0;
    if ( convert_time($atimearr[$i]) - convert_time($deztmptime) > $rectime ) {
      printf REPORT "1DEAMZT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $deztmptime, $deztmppos, $adezmin, $adezmax,$hsadezmin,$hsadezmax;
      printf REPORT "1DEAMZT  Recovery at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f\n", $atimearr[$i], $adezarr[$i], $adezmin, $adezmax;
    }
  }

} # for #atimearr
# Report violations that do not exhibit recovery
if ( $pinviol == 1 ) {
      printf REPORT "1PIN1AT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $pintmptime, $pintmppos, $apinmin, $apinmax,$hsapinmin,$hsapinmax;
}
if ( $pdaviol == 1 ) {
      printf REPORT "1PDEAAT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $pdatmptime, $pdatmppos, $apdamin, $apdamax,$hsapdamin,$hsapdamax;
}
if ( $pdbviol == 1 ) {
      printf REPORT "1PDEABT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $pdbtmptime, $pdbtmppos, $apdbmin, $apdbmax,$hsapdbmin,$hsapdbmax;
}
if ( $dpyviol == 1 ) {
      printf REPORT "1DPAMYT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $dpytmptime, $dpytmppos, $adpymin, $adpymax,$hsadpymin,$hsadpymax;
}
if ( $dpzviol == 1 ) {
      printf REPORT "1DPAMZT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $dpztmptime, $dpztmppos, $adpzmin, $adpzmax,$hsadpzmin,$hsadpzmax;
}
if ( $dezviol == 1 ) {
      printf REPORT "1DEAMZT  Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f Health & Safety limits: %7.2f,%7.2f\n", $deztmptime, $deztmppos, $adezmin, $adezmax,$hsadezmin,$hsadezmax;
}

close REPORT;

# ******************************************************************
# iru checks
#  gyro current gets noisy above its limit, so we treat differently
#   than the others.  Here look for 2-hour mode above the limit 
#   instead of $rectime above limit.
my $iruviol = 0;
my $maxairu1g1i = 0;
my $maxirutmptime = 0;
my @sec_itimearr;
for ($i=0;$i<=$#itimearr;$i++) {
  $sec_itimearr[$i]=convert_time($itimearr[$i]);
}
#@sec_itimearr = map convert_time, @itimearr;
open REPORT, "> $ioutfile";
$starti=0;
$stopi=0;
$itimespan=7200; # sec over which to compute mode
while ($sec_itimearr[$stopi]-$sec_itimearr[$starti] < $itimespan && $stopi < $#itimearr) {
  $stopi++;
  #print "m $stopi\n"; #debugmode
}
#open (ITESTOUT,">xitest.out"); #debugmode
for ( $i=$stopi; $i<$#itimearr; $i+=500 ) {  # check every 200th data point
                                            # or it's really slow
  #print "IRU $i $#itimearr\n"; #debugggg
  my $stats = new Statistics::Descriptive::Discrete;
  while ($sec_itimearr[$i]-$sec_itimearr[$starti] > $itimespan) {
    $starti++;
    #print "s $starti\n";
  }
  $stats->add_data(@airu1g1iarr[$starti..$i]);
  $mode=$stats->mode();
  #print "$mode\n"; #debugmode
  #printf ITESTOUT "$i $sec_itimearr[$i] $itimearr[$i] $mode\n"; # debugmode
  if ( $mode > $airu1g1i_lim) {
    printf REPORT "AIRU1G1I  Violation at %19s Mode: %7.2f Limit: %7.2f mAmp\n", $itimearr[$i], $mode, $airu1g1i_lim;
    $i=$#itimearr+1; # found a violation, so stop
    #print "e $mode\n"; #debugmode
  } # if $stats->mode
} # for #itimearr

close REPORT;
#close ITESTOUT; #debugmode

# ******************************************************************
# ephin checks
open REPORT, "> $eoutfile";
open REPORTV, "> $evoutfile";
my $tephinviol = 0;
my $tephin102viol = 0;
my $eph27vviol = 0;
my $eboxviol = 0;
my $last27s=0;
#my $trectime = 120; #set rectime to 2 min for this one
my $trectime = 240; # 120 not enough to avoid bad data 
$jj=0;
for ( $i=0; $i<$#itimearr; $i+=2 ) {  # check every 200th data point
                                            # or it's really slow
  #print "EPH $i $#itimearr $mnframarr[$i] $eph27sarr[$i] $eph27varr[$i]\n"; # debuggggg
  # send another alert if temp exceeds 102 F
  if ( ($tephinarr[$i]) > 102.00 && $tephin102viol == 0) {
    $tephin102viol=1;
    close REPORT;  #start report over
    open REPORT, "> $eoutfile";
    if (! -s "./.dumps_mon_eph102_lock") {
      `cp .dumps_mon_eph_lock .dumps_mon_eph102_lock`;
      unlink ".dumps_mon_eph_lock"; # force rearming
    }
  }
    
  if ( ($tephinarr[$i]) > $tephin_lim && $tephinviol == 0) {
    $tephinviol = 1;
    $tephintmptime = $itimearr[$i];
    $tephintmppos = $tephinarr[$i];
  } elsif ( ($tephinarr[$i]) < $tephin_lim && $tephinviol == 1) {
    $tephinviol = 0;
    if ( convert_time($itimearr[$i]) - convert_time($tephintmptime) > $trectime ) {
      printf REPORT " TEPHIN    Violation at %19s Value: %7.2f Limit: \< %7.2f deg F\n", $tephintmptime, $tephintmppos, $tephin_lim;
      printf REPORT " TEPHIN    Recovery at %19s Value: %7.2f Limit: \< %7.2f deg F\n", $itimearr[$i], $tephinarr[$i], $tephin_lim;
    }
  } # if ( ($tephinarr[$i]) > $tephin_lim && $tephinviol == 0) {

  if ( ($eboxarr[$i]) > $ebox_lim && $eboxviol == 0) {
    $eboxviol = 1;
    $eboxtmptime = $itimearr[$i];
    $eboxtmppos = $eboxarr[$i];
  } elsif ( ($eboxarr[$i]) < $ebox_lim && $eboxviol == 1) {
    $eboxviol = 0;
    if ( convert_time($itimearr[$i]) - convert_time($eboxtmptime) > $trectime ) {
      printf REPORT " EPHIN EBOX (5EHSE300)   Violation at %19s Value: %7.2f Limit: \< %7.2f deg F\n", $eboxtmptime, $eboxtmppos, $ebox_lim;
      printf REPORT " EPHIN EBOX (5EHSE300)   Recovery at %19s Value: %7.2f Limit: \< %7.2f deg F\n", $itimearr[$i], $eboxarr[$i], $ebox_lim;
    }
  } # if ( ($eboxarr[$i]) > $ebox_lim && $eboxviol == 0) {

  if ( $mnframarr[$i] > 20 && $mnframarr[$i] < 108 && $eph27sarr[$i] == $last27s && ($eph27sarr[$i]+1) % 2 == 1) {  # only check if we know eph27v shows voltage
    #if ( ($mnframarr[$i]) > 4 && $eph27sarr[$i] != $last27s && ($eph27sarr[$i]+1) % 2 == 0 && $eph27varr[$i] < $eph27v_lim && $eph27vviol == 0) {
    if ( $eph27varr[$i] < $eph27v_lim && $eph27vviol == 0) {
      $eph27vviol = 1;
      $eph27vtmptime = $itimearr[$i];
      $eph27vtmppos = $eph27varr[$i];
    } elsif ( ($eph27varr[$i]) > $eph27v_lim && $eph27vviol == 1) {
      $eph27vviol = 0;
      if ( convert_time($itimearr[$i]) - convert_time($eph27vtmptime) > $trectime ) {
        printf REPORTV " EPHIN HKP27V  Violation at %19s Value: %7.2f Limit: \> %7.2f V\n", $eph27vtmptime, $eph27vtmppos, $eph27v_lim;
        printf REPORTV " EPHIN HKP27V  Recovery at %19s Value: %7.2f Limit: \> %7.2f V\n", $itimearr[$i], $eph27varr[$i], $eph27v_lim;
      }
    } # if ( $eph27varr[$i] < $eph27v_lim && $eph27vviol == 0) {
  } #if ( ($mnframarr[$i]) > 4 && $eph27sarr[$i] != $last27s && ($eph27sarr[$i]+1) % 2 == 0) {  # only check if we know eph27v shows voltage
  $last27s=$eph27sarr[$i];
  $jj+=2;  # scheme to look at a few frames in order then skip a bunch
  if ($jj == 16) { $i+=120; }
  if ($jj == 32) {
    $i+=1387;
    $jj=0;
   } # if ($jj == 32) {
} # for ( $i=0; $i<$#itimearr; $i++ ) {
if ( $tephinviol == 1 ) {
      printf REPORT " TEPHIN    Violation at %19s Value: %7.2f Limit: \< %7.2f deg F\n", $tephintmptime, $tephintmppos, $tephin_lim;
}
if ( $eboxviol == 1 ) {
      printf REPORT " EPHIN EBOX (5EHSE300)    Violation at %19s Value: %7.2f Limit: \< %7.2f deg C\n", $eboxtmptime, $eboxtmppos, $ebox_lim;
}
if ( $eph27vviol == 1 ) {
      printf REPORTV " EPHIN HKP27V  Violation at %19s Value: %7.2f Limit: \> %7.2f V\n", $eph27vtmptime, $eph27vtmppos, $eph27v_lim;
}
close REPORT;
close REPORTV;

# ******************************************************************
# mups pline checks
open REPORT, "> $poutfile";
my $pline04viol=0;
my $trectime = 120; # 
$jj=0;
for ( $i=0; $i<$#mtimearr; $i+=2 ) {  # 
  if ( ($pline04arr[$i]) < $pline04_lim && $pline04viol == 0) {
    $pline04viol = 1;
    $pline04tmptime = $mtimearr[$i];
    $pline04tmppos = $pline04arr[$i];
  } elsif ( ($pline04arr[$i]) > $pline04_lim && $pline04viol == 1) {
    $pline04viol = 0;
    if ( convert_time($mtimearr[$i]) - convert_time($pline04tmptime) > $trectime ) {
      printf REPORT " PLINE04   Violation at %19s Value: %7.2f Limit: \> %7.2f deg F\n", $pline04tmptime, $pline04tmppos, $pline04_lim;
      printf REPORT " PLINE04   Recovery at %19s Value: %7.2f Limit: \> %7.2f deg F\n", $mtimearr[$i], $pline04arr[$i], $pline04_lim;
    }
  } # if ( ($pline04arr[$i]) < $pline04_lim && $pline04viol == 0) {

} # for ( $i=0; $i<$#mtimearr; $i++ ) {
if ( $pline04viol == 1 ) {
      printf REPORT " PLINE04   Violation at %19s Value: %7.2f Limit: \> %7.2f deg F\n", $pline04tmptime, $pline04tmppos, $pline04_lim;
}
close REPORT;

# ******************************************************************
# acis dea hk temp checks
my $deahk1viol = 0;
my $deahk2viol = 0;
my $deahk3viol = 0;
my $deahk4viol = 0;
my $deahk5viol = 0;
my $deahk6viol = 0;
my $deahk7viol = 0;
my $deahk8viol = 0;
my $deahk9viol = 0;
my $deahk10viol = 0;
my $deahk11viol = 0;
my $deahk12viol = 0;
# ****** acis dea temp limits degC
my $deat1min = 8.0;
my $deat1max = 23.0;
my $deat2min = 6.0;
my $deat2max = 22.0;
my $deat3min = 11.5;
my $deat3max = 27.5;
my $deat4min = 9.0;
my $deat4max = 24.0;
my $deat5min = 10.0;
my $deat5max = 27.5;
my $deat6min = 10.0;
my $deat6max = 27.5;
my $deat7min = 6.0;
my $deat7max = 21.0;
my $deat8min = 11.5;
my $deat8max = 28.5;
my $deat9min = 9.0;
my $deat9max = 25.0;
my $deat10min = 11.5;
my $deat10max = 28.5;
my $deat11min = 10.5;
my $deat11max = 27.5;
my $deat12min = 6.0;
my $deat12max = 22.0;

$j = 0;
open REPORT, "> $doutfile";
for ( $i=0; $i<$#dttimearr; $i++ ) {
  #print "DEA $i $#dttimearr\n"; # debuggggg

  if ( $deatemp1[$i] != 0 && ($deatemp1[$i] <= $deat1min || $deatemp1[$i] >= $deat1max) && $deahk1viol == 0) {
    $deahk1viol = 1;
    $deat1intmptime = $dttimearr[$i];
    $deat1intmppos = $deatemp1[$i];
  }
  if ( $deatemp1[$i] ne "" && $deatemp1[$i] > $deat1min && $deatemp1[$i] < $deat1max && $deahk1viol == 1) {
    $deahk1viol = 0;
    if ( $dttimearr[$i] - $deat1intmptime > $rectime ) {
      printf REPORT "DPAHK1 BEP PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat1intmptime u s u d`, $deat1intmppos, $deat1min, $deat1max;
      printf REPORT "DPAHK1  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp1[$i], $deat1min, $deat1max;
    }
  }
  if ( $deatemp2[$i] != 0 && ($deatemp2[$i] <= $deat2min || $deatemp2[$i] >= $deat2max) && $deahk2viol == 0) {
    $deahk2viol = 1;
    $deat2intmptime = $dttimearr[$i];
    $deat2intmppos = $deatemp2[$i];
  }
  if ( $deatemp2[$i] ne "" && $deatemp2[$i] > $deat2min && $deatemp2[$i] < $deat2max && $deahk2viol == 1) {
    $deahk2viol = 0;
    if ( $dttimearr[$i] - $deat2intmptime > $rectime ) {
      printf REPORT "DPAHK2 BEP Oscillator Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat2intmptime u s u d`, $deat2intmppos, $deat2min, $deat2max;
      printf REPORT "DPAHK2  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp2[$i], $deat2min, $deat2max;
    }
  }
  if ( $deatemp3[$i] != 0 && ($deatemp3[$i] <= $deat3min || $deatemp3[$i] >= $deat3max) && $deahk3viol == 0) {
    $deahk3viol = 1;
    $deat3intmptime = $dttimearr[$i];
    $deat3intmppos = $deatemp3[$i];
  }
  if ( $deatemp3[$i] ne "" && $deatemp3[$i] > $deat3min && $deatemp3[$i] < $deat3max && $deahk3viol == 1) {
    $deahk3viol = 0;
    if ( $dttimearr[$i] - $deat3intmptime > $rectime ) {
      printf REPORT "DPAHK3 FEP 0 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat3intmptime u s u d`, $deat3intmppos, $deat3min, $deat3max;
      printf REPORT "DPAHK3  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp3[$i], $deat3min, $deat3max;
    }
  }
  if ( $deatemp4[$i] != 0 && ($deatemp4[$i] <= $deat4min || $deatemp4[$i] >= $deat4max) && $deahk4viol == 0) {
    $deahk4viol = 1;
    $deat4intmptime = $dttimearr[$i];
    $deat4intmppos = $deatemp4[$i];
  }
  if ( $deatemp4[$i] ne "" && $deatemp4[$i] > $deat4min && $deatemp4[$i] < $deat4max && $deahk4viol == 1) {
    $deahk4viol = 0;
    if ( $dttimearr[$i] - $deat4intmptime > $rectime ) {
      printf REPORT "DPAHK4 FEP 0 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat4intmptime u s u d`, $deat4intmppos, $deat4min, $deat4max;
      printf REPORT "DPAHK4  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp4[$i], $deat4min, $deat4max;
    }
  }
  if ( $deatemp5[$i] != 0 && ($deatemp5[$i] <= $deat5min || $deatemp5[$i] >= $deat5max) && $deahk5viol == 0) {
    $deahk5viol = 1;
    $deat5intmptime = $dttimearr[$i];
    $deat5intmppos = $deatemp5[$i];
  }
  if ( $deatemp5[$i] ne "" && $deatemp5[$i] > $deat5min && $deatemp5[$i] < $deat5max && $deahk5viol == 1) {
    $deahk5viol = 0;
    if ( $dttimearr[$i] - $deat5intmptime > $rectime ) {
      printf REPORT "DPAHK5 FEP 0 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat5intmptime u s u d`, $deat5intmppos, $deat5min, $deat5max;
      printf REPORT "DPAHK5  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp5[$i], $deat5min, $deat5max;
    }
  }
  if ( $deatemp6[$i] != 0 && ($deatemp6[$i] <= $deat6min || $deatemp6[$i] >= $deat6max) && $deahk6viol == 0) {
    $deahk6viol = 1;
    $deat6intmptime = $dttimearr[$i];
    $deat6intmppos = $deatemp6[$i];
  }
  if ( $deatemp6[$i] ne "" && $deatemp6[$i] > $deat6min && $deatemp6[$i] < $deat6max && $deahk6viol == 1) {
    $deahk6viol = 0;
    if ( $dttimearr[$i] - $deat6intmptime > $rectime ) {
      printf REPORT "DPAHK6 FEP 0 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat6intmptime u s u d`, $deat6intmppos, $deat6min, $deat6max;
      printf REPORT "DPAHK6  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp6[$i], $deat6min, $deat6max;
    }
  }
  if ( $deatemp7[$i] != 0 && ($deatemp7[$i] <= $deat7min || $deatemp7[$i] >= $deat7max) && $deahk7viol == 0) {
    $deahk7viol = 1;
    $deat7intmptime = $dttimearr[$i];
    $deat7intmppos = $deatemp7[$i];
  }
  if ( $deatemp7[$i] ne "" && $deatemp7[$i] > $deat7min && $deatemp7[$i] < $deat7max && $deahk7viol == 1) {
    $deahk7viol = 0;
    if ( $dttimearr[$i] - $deat7intmptime > $rectime ) {
      printf REPORT "DPAHK7 FEP 0 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat7intmptime u s u d`, $deat7intmppos, $deat7min, $deat7max;
      printf REPORT "DPAHK7  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp7[$i], $deat7min, $deat7max;
    }
  }
  if ( $deatemp8[$i] != 0 && ($deatemp8[$i] <= $deat8min || $deatemp8[$i] >= $deat8max) && $deahk8viol == 0) {
    $deahk8viol = 1;
    $deat8intmptime = $dttimearr[$i];
    $deat8intmppos = $deatemp8[$i];
  }
  if ( $deatemp8[$i] ne "" && $deatemp8[$i] > $deat8min && $deatemp8[$i] < $deat8max && $deahk8viol == 1) {
    $deahk8viol = 0;
    if ( $dttimearr[$i] - $deat8intmptime > $rectime ) {
      printf REPORT "DPAHK8 FEP 1 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat8intmptime u s u d`, $deat8intmppos, $deat8min, $deat8max;
      printf REPORT "DPAHK8  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp8[$i], $deat8min, $deat8max;
    }
  }
  if ( $deatemp9[$i] != 0 && ($deatemp9[$i] <= $deat9min || $deatemp9[$i] >= $deat9max) && $deahk9viol == 0) {
    $deahk9viol = 1;
    $deat9intmptime = $dttimearr[$i];
    $deat9intmppos = $deatemp9[$i];
  }
  if ( $deatemp9[$i] ne "" && $deatemp9[$i] > $deat9min && $deatemp9[$i] < $deat9max && $deahk9viol == 1) {
    $deahk9viol = 0;
    if ( $dttimearr[$i] - $deat9intmptime > $rectime ) {
      printf REPORT "DPAHK9 FEP 1 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat9intmptime u s u d`, $deat9intmppos, $deat9min, $deat9max;
      printf REPORT "DPAHK9  Recovery at %19s Value: %7.2f \n", `axTime3 $dttimearr[$i] u s u d`, $deatemp9[$i], $deat9min, $deat9max;
    }
  }
  if ( $deatemp10[$i] != 0 && ($deatemp10[$i] <= $deat10min || $deatemp10[$i] >= $deat10max) && $deahk10viol == 0) {
    $deahk10viol = 1;
    $deat10intmptime = $dttimearr[$i];
    $deat10intmppos = $deatemp10[$i];
  }
  if ( $deatemp10[$i] ne "" && $deatemp10[$i] > $deat10min && $deatemp10[$i] < $deat10max && $deahk10viol == 1) {
    $deahk10viol = 0;
    if ( $dttimearr[$i] - $deat10intmptime > $rectime ) {
      printf REPORT "DPAHK10 FEP 1 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat10intmptime u s u d`, $deat10intmppos, $deat10min, $deat10max;
      printf REPORT "DPAHK10  Recovery at %19s Value: %7.2f\n", `axTime3 $dttimearr[$i] u s u d`, $deatemp10[$i], $deat10min, $deat10max;
    }
  }
  if ( $deatemp11[$i] != 0 && ($deatemp11[$i] <= $deat11min || $deatemp11[$i] >= $deat11max) && $deahk11viol == 0) {
    $deahk11viol = 1;
    $deat11intmptime = $dttimearr[$i];
    $deat11intmppos = $deatemp11[$i];
  }
  if ( $deatemp11[$i] ne "" && $deatemp11[$i] > $deat11min && $deatemp11[$i] < $deat11max && $deahk11viol == 1) {
    $deahk11viol = 0;
    if ( $dttimearr[$i] - $deat11intmptime > $rectime ) {
      printf REPORT "DPAHK11 FEP 1 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat11intmptime u s u d`, $deat11intmppos, $deat11min, $deat11max;
      printf REPORT "DPAHK11  Recovery at %19s Value: %7.2f\n", `axTime3 $dttimearr[$i] u s u d`, $deatemp11[$i], $deat11min, $deat11max;
    }
  }
  if ( $deatemp12[$i] != 0 && ($deatemp12[$i] <= $deat12min || $deatemp12[$i] >= $deat12max) && $deahk12viol == 0) {
    $deahk12viol = 1;
    $deat12intmptime = $dttimearr[$i];
    $deat12intmppos = $deatemp12[$i];
  }
  if ( $deatemp12[$i] ne "" && $deatemp12[$i] > $deat12min && $deatemp12[$i] < $deat12max && $deahk12viol == 1) {
    $deahk12viol = 0;
    if ( $dttimearr[$i] - $deat12intmptime > $rectime ) {
      printf REPORT "DPAHK12 FEP 1 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat12intmptime u s u d`, $deat12intmppos, $deat12min, $deat12max;
      printf REPORT "DPAHK12  Recovery at %19s Value: %7.2f\n", `axTime3 $dttimearr[$i] u s u d`, $deatemp12[$i], $deat12min, $deat12max;
    }
  }

} # for #dttimearr
# Report violations that do not exhibit recovery
if ( $deahk1viol == 1 ) {
      printf REPORT "DPAHK1 BEP PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat1intmptime u s u d`, $deat1intmppos, $deat1min, $deat1max;
}
if ( $deahk2viol == 2 ) {
      printf REPORT "DPAHK2 BEP Oscillator Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat2intmptime u s u d`, $deat2intmppos, $deat2min, $deat2max;
}
if ( $deahk3viol == 1 ) {
      printf REPORT "DPAHK3 FEP 0 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat3intmptime u s u d`, $deat3intmppos, $deat3min, $deat3max;
}
if ( $deahk4viol == 1 ) {
      printf REPORT "DPAHK4 FEP 0 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat4intmptime u s u d`, $deat4intmppos, $deat4min, $deat4max;
}
if ( $deahk5viol == 1 ) {
      printf REPORT "DPAHK5 FEP 0 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat5intmptime u s u d`, $deat5intmppos, $deat5min, $deat5max;
}
if ( $deahk6viol == 1 ) {
      printf REPORT "DPAHK6 FEP 0 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat6intmptime u s u d`, $deat6intmppos, $deat6min, $deat6max;
}
if ( $deahk7viol == 1 ) {
      printf REPORT "DPAHK7 FEP 0 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat7intmptime u s u d`, $deat7intmppos, $deat7min, $deat7max;
}
if ( $deahk8viol == 1 ) {
      printf REPORT "DPAHK8 FEP 1 Mongoose Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat8intmptime u s u d`, $deat8intmppos, $deat8min, $deat8max;
}
if ( $deahk9viol == 1 ) {
      printf REPORT "DPAHK9 FEP 1 PC Board Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat9intmptime u s u d`, $deat9intmppos, $deat9min, $deat9max;
}
if ( $deahk10viol == 1 ) {
      printf REPORT "DPAHK10 FEP 1 ACTEL Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat10intmptime u s u d`, $deat10intmppos, $deat10min, $deat10max;
}
if ( $deahk11viol == 1 ) {
      printf REPORT "DPAHK11 FEP 1 RAM Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat11intmptime u s u d`, $deat11intmppos, $deat11min, $deat11max;
}
if ( $deahk12viol == 1 ) {
      printf REPORT "DPAHK12 FEP 1 Frame Buf. Violation at %19s Value: %7.2f Data Quality limits: %7.2f,%7.2f C\n", `axTime3 $deat12intmptime u s u d`, $deat12intmppos, $deat12min, $deat12max;
}

close REPORT;

# *******************************************************************
#  E-mail violations, if any
# *******************************************************************
if ( -s "testfile.out" ) {
  open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu";
  print MAIL "config_mon_2.4 \n\n"; # current version
  if ( -s $dumpname ) {
    open DNAME, "<$dumpname";
    while (<DNAME>) {
      print MAIL $_;
    }
  }
  print MAIL "\n";
  open REPORT, "< testfile.out";
  
  while (<REPORT>) {
    print MAIL $_;
  }
  print MAIL "This message sent to brad\n";
  close MAIL;
}

#  E-mail violations, if any
my $lockfile = "./.dumps_mon_lock";
my $safefile = "/home/mta/Snap/.scs107alert";  # lock created by snapshot
if ( -s $outfile ) {
  if ( -s $lockfile || -s $safefile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$outfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    open MAIL, "|mailx -s config_mon sot_lead\@head-cfa.harvard.edu brad jnichols";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    #open MAIL, "|mail brad\@head-cfa.harvard.edu swolk\@head-cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$outfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    print MAIL "This message sent to sot_lead brad jnichols\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad1\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $outfile;

# *******************************************************************
#  E-mail acis violations, if any
# *******************************************************************
#  E-mail violations, if any
$lockfile = "./.dumps_mon_acis_lock";
if ( -s $aoutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    #open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu plucinsk";
    open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu acisdude";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$aoutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon das plucinsk depasq brad swolk jnichols nadams goeke\@space.mit.edu eab\@space.mit.edu";
    #open MAIL, "|mail brad\@head-cfa.harvard.edu swolk\@head-cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$aoutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad1\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $aoutfile;

# *******************************************************************
#  E-mail acis dea hk temp violations, if any
# *******************************************************************
#  E-mail violations, if any
$lockfile = "./.dumps_mon_deatemp_lock";
if ( -s $doutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    #open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu plucinsk";
    open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$doutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    open MAIL, "|mailx -s config_mon das plucinsk depasq brad swolk jnichols nadams goeke\@space.mit.edu eab\@space.mit.edu";
    #open MAIL, "|mail brad\@head-cfa.harvard.edu swolk\@head-cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$doutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad1\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $doutfile;

# *******************************************************************
#  E-mail iru violations, if any
# *******************************************************************
$lockfile = "./.dumps_mon_iru_lock";
if ( -s $ioutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu 6172573986\@mobile.mycingular.com";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$ioutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad brad1\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    open MAIL, "|mailx -s config_mon brad\@head-cfa.harvard.edu 6172573986\@mobile.mycingular.com";
    #open MAIL, "|mailx -s config_mon sot_red_alert\@head-cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$ioutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to sot_red_alert\n";
    print MAIL "This message sent to brad brad1\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $ioutfile;
# *******************************************************************
#  E-mail ephin violations, if any
# *******************************************************************
$lockfile = "./.dumps_mon_eph_lock";
if ( -s $eoutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "xconfig_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$eoutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon brad";
    open MAIL, "|mailx -s config_mon sot_lead brad";
    #open MAIL, "|mailx -s config_mon sot_red_alert\@head-cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$eoutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to sot_red_alert\n";
    #print MAIL "This message sent to brad swolk\n";  #turnbackon
    print MAIL "This message sent to sot_lead\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";  #turnbackon
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
  unlink "./.dumps_mon_eph102_lock";
}
unlink $eoutfile;
$lockfile = "./.dumps_mon_ephv_lock";
if ( -s $evoutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon brad\@head.cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$evoutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    #open MAIL, "|mailx -s config_mon brad swolk";
    #open MAIL, "|mailx -s config_mon sot_lead brad";
    open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$evoutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to brad swolk\n";
    #print MAIL "This message sent to brad1\n";
    #print MAIL "This message sent to sot_lead\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $evoutfile;

# *******************************************************************
#  E-mail pline violations, if any
# *******************************************************************
$lockfile = "./.dumps_mon_mups_lock";
if ( -s $poutfile ) {
  if ( -s $lockfile ) {  # already sent, don't send again
    open MAIL, "|mailx -s config_mon brad\@head.cfa.harvard.edu";
    print MAIL "xconfig_mon_2.4 \n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$poutfile";
    `date >> $lockfile`;
    open LOCK, ">> $lockfile";
    
    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    print MAIL "This message sent to brad\n";
    close MAIL;
    close LOCK;
  } else {  # first violation, tell someone
    open MAIL, "|mailx -s config_mon sot_lead brad";
    #open MAIL, "|mailx -s config_mon sot_yellow_alert\@head-cfa.harvard.edu";
    #open MAIL, "|more"; #debug
    print MAIL "config_mon_2.4\n\n"; # current version
    if ( -s $dumpname ) {
      open DNAME, "<$dumpname";
      while (<DNAME>) {
        print MAIL $_;
      }
    }
    print MAIL "\n";
    open REPORT, "<$poutfile";

    `date > $lockfile`;
    open LOCK, ">> $lockfile";

    while (<REPORT>) {
      print MAIL $_;
      print LOCK $_;
    }
    #print MAIL "Future violations will not be reported until rearmed by MTA.\n";
    #print MAIL "This message sent to sot_yellow_alert\n";
    #print MAIL "This message sent to sot_red_alert\n";
    #print MAIL "This message sent to brad swolk\n";  #turnbackon
    print MAIL "This message sent to sot_lead\n";
    #print MAIL "TEST_MODE TEST_MODE TEST_MODE\n";  #turnbackon
    close MAIL;
    close LOCK;
  }  #endelse

} else { # no violation, rearm alert
  unlink $lockfile;
}
unlink $poutfile;
# end **************************************************************

sub parse_args {
    my $cinfile_found = 0;
    my $pinfile_found = 0;
    my $ainfile_found = 0;
    my $ginfile_found = 0;
    my $dinfile_found = 0;
    my $minfile_found = 0;
    
    for ($ii = 0; $ii <= $#ARGV; $ii++) {
	if (!($ARGV[$ii] =~ /^-/)) {
	    next;
	}

	# -c <infile>
	if ($ARGV[$ii] =~ /^-c/) {
	    $cinfile_found = 1;
	    if ($ARGV[$ii] =~ /^-c$/) {
		$ii++;
		$cinfile = $ARGV[$ii];	    
	    }
	    else {
		$cinfile = substr($ARGV[$ii], 2);
	    }	    
	} # if ($ARGV[$ii] =~ /^-c/)

	# -p <infile>
	if ($ARGV[$ii] =~ /^-p/) {
	    $pinfile_found = 1;
	    if ($ARGV[$ii] =~ /^-p$/) {
		$ii++;
		$pinfile = $ARGV[$ii];	    
	    }
	    else {
		$pinfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-p/)

	# -a <infile>
	if ($ARGV[$ii] =~ /^-a/) {
	    $ainfile_found = 1;
	    if ($ARGV[$ii] =~ /^-a$/) {
		$ii++;
		$ainfile = $ARGV[$ii];	    
	    }
	    else {
		$ainfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-a/)

	# -g <infile>
	if ($ARGV[$ii] =~ /^-g/) {
	    $ginfile_found = 1;
	    if ($ARGV[$ii] =~ /^-g$/) {
		$ii++;
		$ginfile = $ARGV[$ii];	    
	    }
	    else {
		$ginfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-g/)

	# -d <infile>
	if ($ARGV[$ii] =~ /^-d/) {
	    $dinfile_found = 1;
	    if ($ARGV[$ii] =~ /^-d$/) {
		$ii++;
		$dtinfile = $ARGV[$ii];	    
	    }
	    else {
		$dtinfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-d/)

	# -m <infile>
	if ($ARGV[$ii] =~ /^-m/) {
	    $minfile_found = 1;
	    if ($ARGV[$ii] =~ /^-m$/) {
		$ii++;
		$mupsfile = $ARGV[$ii];	    
	    }
	    else {
		$mupsfile = substr($ARGV[$ii], 2);
	    }
	} # if ($ARGV[$ii] =~ /^-d/)

        # -v<verbose>
        if ($ARGV[$ii] =~ /^-v/) {
            #$verbose_found = 1;
            if ($ARGV[$ii] =~ /^-v$/) {
                $ii++;
                $verbose = $ARGV[$ii];
            }
            else {
                $verbose = substr($ARGV[$ii], 2);
            }

        } # if ($ARGV[$ii] =~ /^-v/)
        # -h
        if ($ARGV[$ii] =~ /^-h/) {
            goto USAGE;
        } # if ($ARGV[$ii] =~ /^-h/)
    } #  for ($ii = 0; $ii <= $#ARGV; $ii++)

    if (!$cinfile_found || !$pinfile_found) {
	goto USAGE;
    }

    return;

  USAGE:
    print "Usage:\n\t$0 -c<ccdm infile> -p<pcad infile> [-v<verbose>]\n";
    exit (0);
}

#sub abs {
  #if ( $_ >= 0 ) {
    #return $_;
  #}
  #else {
    #return ($_ * -1);
  #}
#}
    
sub quat_to_euler {
    use Math::Trig;
    my @quat = @_;
    $RAD_PER_DEGREE = pi / 180.0;
    
    my $q1 = $quat[0];
    my $q2 = $quat[1];
    my $q3 = $quat[2];
    my $q4 = $quat[3];
    
    my $q12 = 2.0 * $q1 * $q1;
    my $q22 = 2.0 * $q2 * $q2;
    my $q32 = 2.0 * $q3 * $q3;
    
    my @T = (
	     [ 1.0 - $q22 - $q32, 2.0 * ($q1 * $q2 + $q3 * $q4), 2.0 * ($q3 * $q1 - $q2 * $q4) ],
	     [ 2.0 * ($q1 * $q2 - $q3 * $q4), 1.0 - $q32 - $q12,  2 * ($q2 * $q3 + $q4 * $q1) ],
	     [ 2.0 * ($q3 * $q1 + $q2 * $q4), 2.0 * ($q2 * $q3 - $q1 * $q4), 1.0 - $q12 - $q22 ]
	     );


    my %eci;

    $eci{ra}   = atan2($T[0][1], $T[0][0]);
    $eci{dec}  = atan2($T[0][2], sqrt($T[0][0] * $T[0][0] + $T[0][1] * $T[0][1]));
    $eci{roll} = atan2($T[2][0] * sin($eci{ra}) - $T[2][1] * cos($eci{ra}), -$T[1][0] * sin($eci{ra}) + $T[1][1] * cos($eci{ra}));
    

    $eci{ra}   /= $RAD_PER_DEGREE;
    $eci{dec}  /= $RAD_PER_DEGREE;
    $eci{roll} /= $RAD_PER_DEGREE;

    if ($eci{ra}   < 0.0)  {
	$eci{ra} += 360.0;
    }
    if ($eci{roll} < -1e-13) {
	$eci{roll} += 360.0;
    }
    if ($eci{dec}  < -90.0 || $eci{dec} > 90.0) {
	print "Ugh dec $eci{dec}\n";
    }

    return (%eci);
}

sub convert_time {
    my @yrday = split(':', $_[0]);
    my $year = $yrday[0];
    my $day  = $yrday[1];
    my $hour = $yrday[2];
    my $min  = $yrday[3];
    my $sec  = $yrday[4];
    
    #my @hrminsec = split(':', ($yrday[2] . $yrday[3]));
    #my $hour = $hrminsec[0];
    #my $min  = $hrminsec[1];
    #my $sec  = $hrminsec[2];

    my $totsecs = 0;
    $totsecs = $sec;
    $totsecs += $min  * 60;
    $totsecs += $hour * 3600;

    my $totdays = $day;

    if ($year >= 98 && $year < 1900) {
	$year = 1998 + ($year - 98);
    }
    elsif ($year < 98) {
	$year = 2000 + $year;
    }

    # add days for past leap years
    if ($year > 2000)
    {
        # add one for y2k
	$totdays++;
        # Number of years since 2000. -1 for already counted current leap
	$years = $year - 2000 - 1;
	$leaps = int ($years / 4);
	$totdays += $leaps;
    }
    
    $totdays += ($year - 1998) * 365;


    $totsecs += $totdays * 86400;

    return $totsecs;
}

sub index_match {
# chex can return more than one expected state due to
#uncertainty in timing of spacecraft event
#This function returns which expectation most closely matches actual.
  my($val, $lim, @pred) = @_;
  my $i = 0;
  my $diff = $val - $pred[$i];
  while (abs($diff) > $lim && $i <= $#pred) {
    ++$i;
    $diff = $val - $pred[$i];
  }
  return $i;
}
