#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my ($input,$outputDir);

&GetOptions("input=s"=> \$input);

open(my $data, '<', $input) || die "Could not open file $input: $!";

my $prevAbbrev = "";
while (my $line = <$data>) {
    chomp $line;
    my ($proteinAccession,$md5,$seqLen,$analysis,$sigAccesion,$desc,$start,$stop,$score,$status,$date,$intAccesion,$intDesc,$GO) = split(/\t/, $line);
    my($abbrev,$id) = split(/\|/, $proteinAccession);
    if ($abbrev eq $prevAbbrev) {
        print OUT "$line\n";
    }
    else {
        open(OUT,">iprscan_out_$abbrev.tsv");
	print OUT "$line\n";
    }
    $prevAbbrev = $abbrev;
}	
