#!/usr/bin/env perl
use strict;
use warnings;
use JSON;

my ($infile, $names, $outfile) = @ARGV;
die "Usage: perl $0 input.json names.dmp output.tsv\n" unless $outfile;

open my $in,  '<', $infile  or die "Cannot open input file: $!";
open my $out, '>', $outfile or die "Cannot write output file: $!";

# New header format
print $out join("\t", qw(Taxon Value Name UniRuleId)), "\n";

# Create hash to hold name to taxonId
my %name2taxid;

open(my $N, "<", $names) or die $!;
while (<$N>) {
    chomp;
    my ($taxid, $name_txt, undef, $class) = split /\t\|\t?/;
    next unless $class eq 'scientific name';    # only canonical names
    $name2taxid{$name_txt} = $taxid;
}
close $N;

my $json = JSON->new->utf8->allow_nonref;

my $buffer = '';
my $depth  = 0;

while (read($in, my $chunk, 4096)) {
    foreach my $char (split //, $chunk) {
        $buffer .= $char;
        $depth++ if $char eq '{';
        $depth-- if $char eq '}';
        if ($depth == 0 && $buffer =~ /\S/) {
            my $entry;
            eval { $entry = $json->decode($buffer); };
            if ($@) {
                warn "⚠️ Skipping malformed JSON object: $@\n";
            } else {
                process_entry($entry, $out);
            }
            $buffer = '';
        }
    }
}

close $in;
close $out;
print "✅ Conversion complete. Output written to $outfile\n";

sub process_entry {
    my ($entry, $out) = @_;
    my $uniRuleId = $entry->{uniRuleId} // return;

    # Extract name or EC number
    my $annotations = $entry->{mainRule}{annotations} // [];
    my $rec_name = extract_name($annotations);
    return unless $rec_name;

    my $condition_sets = $entry->{mainRule}{conditionSets} // [];

    foreach my $set (@$condition_sets) {
        my $conditions = $set->{conditions} // [];

        my $taxon = '';
        my @values;

        # Collect all condition values, combine InterPro + Panther + FunFam
        foreach my $cond (@$conditions) {
            if ($cond->{type} eq 'taxon') {
                my $cv = $cond->{conditionValues}[0];
                $taxon = $cv->{value} if $cv->{value};
            } else {
                push @values, map { $_->{value} } grep { $_->{value} } @{$cond->{conditionValues}};
            }
        }

        next unless @values;  # skip if no non-taxon values

        my $joined_values = join(",", @values);
	if ($taxon) {
	    my $taxonId = $name2taxid{$taxon};
	    if ($taxonId) {
                print $out join("\t", $taxonId, $joined_values, $rec_name, $uniRuleId), "\n";
	    }
	    else {
                print $out join("\t", 'MISSING', $joined_values, $rec_name, $uniRuleId), "\n";
	    }
	}
	else {
            print $out join("\t", 'NA', $joined_values, $rec_name, $uniRuleId), "\n";
	}
    }
}

sub extract_name {
    my ($annotations) = @_;

    foreach my $ann (@$annotations) {
        my $desc = $ann->{proteinDescription} or next;

        # Attempt fullName
        my $full = $desc->{recommendedName}{fullName}{value};
        return $full if $full;

        # EC numbers fallback
        my $ecs = $desc->{recommendedName}{ecNumbers} // [];
        my @ecs = map { $_->{value} } grep { $_->{value} } @$ecs;
        return join(", ", @ecs) if @ecs;
    }

    return;
}
