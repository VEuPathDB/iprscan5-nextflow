#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;

my ($arbaFile, $pfamFile, $outputFile);

GetOptions(
    "arba=s"   => \$arbaFile,
    "pfam=s"   => \$pfamFile,
    "output=s" => \$outputFile,
) or die "Usage: $0 --arba <arba.tsv> --pfam <pfam.tsv> --output <out.tsv>\n";

die "Missing --arba\n"   unless $arbaFile;
die "Missing --pfam\n"   unless $pfamFile;
die "Missing --output\n" unless $outputFile;

my %arba;
my %pfam;

# -------------------------
# Read ARBA annotations
# -------------------------
open my $ARBA, "<", $arbaFile or die "Cannot open $arbaFile: $!";
while (<$ARBA>) {
    chomp;
    next unless /\S/;

    my ($id, $desc, $tag, $arba_id) = split /\t/;

    push @{ $arba{$id}{desc} }, $desc;
    push @{ $arba{$id}{ids} },  $arba_id;
}
close $ARBA;

# -------------------------
# Read Pfam annotations
# -------------------------
open my $PF, "<", $pfamFile or die "Cannot open $pfamFile: $!";
while (<$PF>) {
    chomp;
    next unless /\S/;

    my ($id, $pf_ids, $pf_descs) = split /\t/;

    my @ids   = split /,/, $pf_ids;
    my @descs = split /,/, $pf_descs;

    push @{ $pfam{$id}{desc} }, @descs;
    push @{ $pfam{$id}{ids} },  @ids;
}
close $PF;

# -------------------------
# Write output
# -------------------------
open my $OUT, ">", $outputFile or die "Cannot write to $outputFile: $!";

my %all_ids = map { $_ => 1 } (keys %arba, keys %pfam);

for my $gene (sort keys %all_ids) {

    my ($desc, $ids);

    if (exists $arba{$gene}) {
        # ARBA takes priority
        $desc = join(", ", @{ $arba{$gene}{desc} });
        $ids  = join(",",  @{ $arba{$gene}{ids} });
    }
    else {
        next unless exists $pfam{$gene};

        my @descs = @{ $pfam{$gene}{desc} };
        my $desc_join = join(", ", @descs);

        # Add "domain-containing protein" ONCE
        $desc = "$desc_join, domain-containing protein";

        my @ids = @{ $pfam{$gene}{ids} };
        $ids = "Pfam:" . join(",", @ids);
    }

    print $OUT join("\t",
        $gene,
        $desc,
        1,
        "",          # PMID
        "IEA",
        $ids,
        "VEuPathDB"
    ), "\n";
}

close $OUT;

print "Wrote output to $outputFile\n";
