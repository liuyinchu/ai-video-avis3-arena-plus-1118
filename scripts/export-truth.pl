use strict;
use warnings;
use JSON::PP;
local $/;
open my $fh, '<', $ARGV[0] or die $!;
my $truth = decode_json(<$fh>)->{truth};
die "missing truth ASD" unless $truth->{available};
die "unexpected ASD units" unless $truth->{parameters}{output_units} eq "m/sqrt(Hz)";
my $freq = $truth->{frequency_hz};
my $asd = $truth->{displacement_asd};
die "unexpected spectral dimensions" unless @$freq == @$asd && @$freq == 10000 && @{$asd->[0]} == 3;
# Only controlled truth ASD and the shared frequency grid cross the archive boundary.
print encode_json({frequency=>$freq, asd=>$asd});
