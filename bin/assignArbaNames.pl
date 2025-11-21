#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;

my ($iprscan, $arbaRules, $lineage, $outputFile);

GetOptions(
    "iprscan=s"   => \$iprscan,
    "arbaRules=s" => \$arbaRules,
    "lineage=s"   => \$lineage,
    "outputFile=s"=> \$outputFile,
) or die "Usage: $0 --iprscan <file> --arbaRules <file> --lineage <lineage> --outputFile <file>\n";

die "Missing required arguments\n" unless $iprscan && $arbaRules && $lineage && $outputFile;

# ---------------- Load ARBA rules ----------------
open my $ARBA, '<', $arbaRules or die "Could not open file $arbaRules: $!";
my %rules;    # rules{taxon}{unirule} = [ { name => ..., values => [...], count => N }, ... ]

# skip header if present (robust: skip if first line starts with 'Taxon' or contains header tokens)
my $first = <$ARBA>;
if (defined $first) {
    chomp $first;
    if ($first =~ /^Taxon\b/i or $first =~ /\bUniRuleId\b/ or $first =~ /^Taxon\tValue\tName\tUniRuleId/) {
        # header detected; do nothing (we already consumed it)
    } else {
        # not a header: process this line as data
        my $line = $first;
        if ($line =~ /\S/) {
            my ($taxonField, $value_str, $name, $unirule) = split /\t/, $line;
            if (defined $unirule) {
                $value_str //= '';
                my @values = map { s/^\s+|\s+$//gr } grep { length($_) } split /,/, $value_str;
                push @{$rules{$taxonField}{$unirule}}, { name => ($name // ''), values => \@values, count => scalar(@values) };
            }
        }
    }
}

while (my $line = <$ARBA>) {
    chomp $line;
    next unless $line =~ /\S/;
    my ($taxonField, $value_str, $name, $unirule) = split /\t/, $line;
    next unless defined $unirule;            # skip malformed lines
    $value_str //= '';
    my @values = map { s/^\s+|\s+$//gr } grep { length($_) } split /,/, $value_str;   # trim whitespace
    push @{$rules{$taxonField}{$unirule}}, { name => ($name // ''), values => \@values, count => scalar(@values) };
}
close $ARBA;

# ---------------- Load Taxon Lineage ----------------
my @taxids;
open(my $LIN, "<", $lineage) or die "Could not open lineage file $lineage: $!";
while (<$LIN>) {
    chomp;
    next unless /\S/;
    push @taxids, $_;
}
close $LIN;

# Build candidate taxons once: only those that actually have rules plus 'NA' if present in rules
my @candidate_taxons = ();
for my $t (@taxids) {
    push @candidate_taxons, $t if exists $rules{$t};
}
push @candidate_taxons, 'NA' if exists $rules{'NA'};

# If no candidate taxons found, still include 'NA' fallback if present in rules, else include nothing
# (this mirrors your previous behavior of trying lineage then NA)
unless (@candidate_taxons) {
    push @candidate_taxons, 'NA' if exists $rules{'NA'};
}

# ---------------- Read and aggregate IPRScan ----------------
# We'll aggregate signatures per protein into a hash:
#   %protein_info = ( protein_id => { sigs => { sig => 1, ... }, analyses => { FunFam => 1, PANTHER => 1, InterPro => 1 } } )

my %protein_info;

open my $IPR, '<', $iprscan or die "Could not open file $iprscan: $!";
while (my $line = <$IPR>) {
    chomp $line;
    next unless $line =~ /\S/;
    my @cols = split /\t/, $line, -1;

    # Defensive: ensure there are enough columns; original expected at least up to $iprAcc
    # Original mapping:
    # ($protein, $md5, $length, $analysis, $sigAcc, $sigDesc, $start, $end, $score, $status, $date, $iprAcc, $iprDesc, $go, $path)
    my ($protein, $md5, $length, $analysis, $sigAcc, $sigDesc, $start, $end, $score, $status, $date, $iprAcc) = @cols[0..11];

    next unless defined $protein and length $protein;

    # init structure
    $protein_info{$protein} //= { sigs => {}, analysis_counts => {} };

    # normalize analysis tokens for counting: track presence of FunFam/PANTHER/InterPro
    if (defined $analysis) {
        if ($analysis eq 'FunFam') {
            $protein_info{$protein}{analysis_counts}{FunFam}++;
        }
        elsif ($analysis eq 'PANTHER') {
            $protein_info{$protein}{analysis_counts}{PANTHER}++;
        }
        else {
            # treat anything else as InterPro id (covers Pfam, Coils, etc.)
            $protein_info{$protein}{analysis_counts}{InterPro}++;
        }
    }

    # collect signatures -- only non-empty and not '-' values
    if (defined $sigAcc && $sigAcc ne '' && $sigAcc ne '-') {
        $protein_info{$protein}{sigs}{$sigAcc} = 1;
    }
    if (defined $iprAcc && $iprAcc ne '' && $iprAcc ne '-') {
        $protein_info{$protein}{sigs}{$iprAcc} = 1;
    }
}
close $IPR;

# ---------------- Apply ARBA rules to each protein ----------------
open my $OUT, '>', $outputFile or die "Cannot write to $outputFile: $!";

my $total_proteins = scalar keys %protein_info;
my $processed = 0;

# printed record guard: printed{$protein}{$unirule} = 1 ensures one output per protein per rule
my %printed;

for my $protein (sort keys %protein_info) {
    $processed++;
    print STDERR "Processed proteins: $processed / $total_proteins\n" if $processed % 1000 == 0;

    # choose analysis label by priority: FunFam > PANTHER > InterPro
    my $analysis_label = 'InterPro id';
    if ($protein_info{$protein}{analysis_counts}{FunFam}) {
        $analysis_label = 'FunFam id';
    } elsif ($protein_info{$protein}{analysis_counts}{PANTHER}) {
        $analysis_label = 'PANTHER id';
    } else {
        $analysis_label = 'InterPro id';
    }

    my $sigs_ref = $protein_info{$protein}{sigs};

    # skip proteins with no collected signatures if you prefer (unlikely to match)
    next unless keys %$sigs_ref;

    # iterate candidate taxons (already filtered to those with rules)
    for my $rule_taxon (@candidate_taxons) {
        next unless exists $rules{$rule_taxon};   # defensive; candidate_taxons was filtered earlier

        # iterate each UniRule id for that taxon
        while (my ($unirule_id, $entries) = each %{ $rules{$rule_taxon} }) {
            for my $rule_entry (@$entries) {
                my $all_present = 1;

                # check all required values exist in the protein signatures
                for my $val (@{ $rule_entry->{values} }) {
                    unless (exists $sigs_ref->{$val}) {
                        $all_present = 0;
                        last;
                    }
                }

                next unless $all_present;

                # only print once per protein per unirule
                next if $printed{$protein}{$unirule_id}++;

                print $OUT join("\t",
                    $protein,
                    $rule_entry->{name} // '',
                    $unirule_id,
                    $analysis_label
                ), "\n";
            }
        }
        # reset each() iterator for the next protein's iteration over same hash
        # (each maintains internal iterator, so re-blessing by keys or use keys() below is simpler)
        # But since we used while(each ...) it already advanced; to be safe, do nothing here, each is local to the hash
    }
}

close $OUT;

print "✅ Assignment complete. Output written to $outputFile\n";
exit 0;
