#!/usr/local/bin/perl -I/spool1/home/gtoly/lib -I/home/gtoly/lib
#===============================================================================
#
#         FILE:  File.pm
#
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Anatoliy Grishaev (), grian@cpan.org
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  10/28/2011 07:48:11 PM
#     REVISION:  ---
#===============================================================================
package Real::Handy::File;
use Real::Handy;

sub mktied(\%$){
	my $folder = $_[1];
	tie %{ $_[0] }, CLASS, $folder;
}
sub _prepare_path{
	if ( $_[1]=~m/\// ){
		my @s = split "/", $_[1];
		pop @s;
		my $b = '';
		for my $s (@s){
			$b .= "/" . $s;
			mkdir $_[0] . $b ;
		}
	}
}
sub TIEHASH{
	my $class = shift; 
	my $path =  $Real::Handy::Workspace . "/". ( $_[0] || 'https-proxy' ) . "/";
	_prepare_path( $Real::Handy::Workspace, $_[0] );
	mkdir $path;
	return bless { path => $path  }, $class;
}
sub FETCH{
	_prepare_path( $_[0]->{path}, $_[1] );
	return $_[0]->{path} . $_[1];
}
clean_namespace;

