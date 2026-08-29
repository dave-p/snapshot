#!/usr/bin/env perl
################################
## Modified from rsnapreport.pl (https://github.com/rsnapshot/rsnapshot)
## Copyright 2006 William Bear
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
################################

use strict;
use warnings;
use English '-no_match_vars';

my $bufsz = 2;
my %bkdata=();
my @sources = glob("*.log");
my $fh;


sub nextLine($){
	my($lines) = @_;
	my $line = <$fh>;
	push(@$lines,$line);
	return shift @$lines;
}

foreach(@sources) {
    my ($source) = ($_ =~ /(.*)\.log/);
    open($fh, '<', $_) or die $!;

    my @rsnapout = ();

# load readahead buffer
    for(my $i=0; $i < $bufsz; $i++){
	$rsnapout[$i] = <$fh>;
    }

    while(my $line = nextLine(\@rsnapout)){
	# Number of files: 1,325 (reg: 387, dir: 139, link: 799)
	if($line =~ /^Number of files:\s+([\d,]+)/){
		$bkdata{$source}{'files'}=$1;
		$bkdata{$source}{'files'}=~ s/,//g;
	}
	# Number of regular files transferred: 1
	elsif($line =~ /^Number of (regular )?files transferred:\s+([\d,]+)/){
		$bkdata{$source}{'files_tran'}=$2;
                $bkdata{$source}{'files_tran'}=~ s/,//g;
	}
	# Number of created files: 0                                    
	elsif($line =~ /^Number of created files:\s+([\d,]+)/){
		$bkdata{$source}{'files_cre'}=$1;      
		$bkdata{$source}{'files_cre'}=~ s/,//g;           
	}                                                         
	# Number of deleted files: 0
#	elsif($line =~ /^Number of deleted files:\s+([\d,]+)/){
#		$bkdata{$source}{'files_del'}=$1;
#		$bkdata{$source}{'files_del'}=~ s/,//g;
#	}
	# Total file size: 1,865,857 bytes
	elsif($line =~ /^Total file size:\s+([\d,]+)/){
		$bkdata{$source}{'file_size'}=$1;
		$bkdata{$source}{'file_size'}=~ s/,//g;
	}
	elsif($line =~ /^Total transferred file size:\s+([\d,]+)/){
		$bkdata{$source}{'file_tran_size'}=$1;
		$bkdata{$source}{'file_tran_size'}=~ s/,//g;
	}
    }
    close($fh);
}

$FORMAT_NAME="BREPORTBODY";
$FORMAT_TOP_NAME="BREPORTHEAD";
select(STDOUT);

format BREPORTHEAD =
SOURCE                    TOTAL FILES   FILES NEW   FILES TRANS    MB TRANS    TOTAL MB
---------------------------------------------------------------------------------------
.

foreach my $source (sort keys %bkdata){
	if($bkdata{$source} =~ /error/i) { print "ERROR $source $bkdata{$source}"; next; }
	my $files = $bkdata{$source}{'files'};
	my $filest = $bkdata{$source}{'files_tran'};
	my $filesc = $bkdata{$source}{'files_cre'};                             
#	my $filesd = $bkdata{$source}{'files_del'};
	my $bytes = $bkdata{$source}{'file_size'}/1000000; # convert to MB
	my $bytest = $bkdata{$source}{'file_tran_size'}/1000000; # convert to MB
	$source =~ s/^[^\@]+\@//; # remove username
	format BREPORTBODY =
@<<<<<<<<<<<<<<<<<<<<     @>>>>>>>>>>   @>>>>>>>>   @>>>>>>>>>> @#######.## @#######.##
$source,                  $files,       $filesc,    $filest,    $bytest,      $bytes
.
	write STDOUT;
}
