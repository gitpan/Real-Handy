package Real::Handy;
our $VERSION = '0.17';
my $warnings = 
  "\x54\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x15"
^ "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00";

sub clean_namespace;
my %clean_namespace;
my @autouse;
my %autouse;
my $utf8 = 0x00800000;
set_autouse( __PACKAGE__ . '=clean_namespace' );
sub set_utf8 { $utf8 = $_[0] ? 0x00800000 : 0 };
our $SKIP_CONFIG;
sub import{
	my $self = shift;
	my $caller = caller;
	$self->customize_module( $caller, \@_ );
    if ( $autouse{ $caller } ){
        # delete ${ $caller . "::" }{AUTOLOAD};
    }
    for my $module ( @autouse ) {
        my $state = $autouse{$module};
        if ( $state->{var} ) {
            for ( @{ $state->{var} } ) {
                my $sym     = substr($_,0,1);
                my $symname = $module . "::" . substr($_,1);
                my $ref     = $sym eq '%' ? \%{$symname} : undef;
                *{ $caller . "::" . substr($_,1) } = $ref;
            }
        }
        if ( $module eq $caller ) {    # Fix: remain own methods untouched
            next;
        }
        if ( $state->{sub} ) {
            for ( @{ $state->{sub} } ) {
				*{ $caller . "::" . $_ } = \&{ $module . "::" . $_ };
				$clean_namespace{$caller}{$_} = 1;
            }
        }
    }
}
sub require_config {
    # set my @INC
    my $workspace;
	my @PWD;
	for  ( map "$_", grep $_, $ENV{'DOCUMENT_ROOT'} ){
		last unless $_;
		s#\w+/?\z##;
		push @PWD, $_;
	};
    for ( $ENV{PWD}, @PWD, $0, $ENV{project} ){
        if (m#(/home/sites/[-\.\w]+|/home/\w+)#){
			my $candidate =  substr $_, 0, $+[0];
			if ( -f "$candidate/config/site.pl" ){
                $workspace = $candidate ;
                last ;
            }
        }
    }
    if ( !$workspace ){
        warn "Can't load proper config ( ENV{project} = '$ENV{project}'";
        return;
    }

    if ( -d ( my $lib = "$workspace/lib" ) ) {
        @INC = grep $_ ne $lib, @INC;
        unshift @INC, $lib;
    }
    $Real::Handy::Workspace = $workspace;
    ( $Real::Handy::WorkName = $workspace ) =~ s/.*\///;
    my $config = "$workspace/config/site.pl";
    if ( -f $config && -s $config ) {
        require $config if $_[0] !~m/config\/site\.pl\z/;
        return;
    }
    warn "no config found at '$config'";
    return;
}

sub customize_module{
    my $self = shift;
    my $caller = shift;
    # strict refs, subs, vars, utf8
    $^H |= ( 0x00000002 | 0x00000200 | 0x00000400 | $utf8 );
    ${^WARNING_BITS} ^= ${^WARNING_BITS} ^ $warnings;
    *{ $caller . '::CLASS' }           = sub () { $caller; } unless exists &{  $caller . '::CLASS' };
	$^H{ $_ } = 1 for qw/feature_say feature_switch feature_state/;
}
my %cleanup_autoload;
sub cleanup_autoload{
    my $s = $cleanup_autoload{ $_[1] };
    $s->() if $s;
    undef;
}
unshift @INC, \&cleanup_autoload;
sub set_autoload {
    my ( $module ) = @_;


    my $AUTOLOAD_var = \${ $module . "::AUTOLOAD" };
    my $require      = "require $module; ";

    s/::/\//g for (my $pm = $module . ".pm");
    my $cleanup = sub { 
        delete ${ $module . "::" }{AUTOLOAD};
        delete $cleanup_autoload{ $pm };
#        print STDERR "Cleanup $module<=>$pm\n";
    };
    $cleanup_autoload{ $pm } = $cleanup;

    if ( !$INC{$pm} || $INC{$pm} eq 'Stub' ) {
        *{ $module . "::AUTOLOAD" } = sub {
            our $AUTOLOAD;
            return if $AUTOLOAD =~ m/\bDESTROY\z/;
            my $autoload = $AUTOLOAD;
            {
                delete ${ $module . "::" }{AUTOLOAD};
                delete $cleanup_autoload{ $pm };
                return if caller() eq $module;
                delete $INC{$pm} if ($INC{$pm}||'') eq 'Stub';
                eval $require;
                die $@ if $@;
            };
            goto &$autoload if exists &$autoload;
            if ( UNIVERSAL::isa( $_[0], $module ) ) {
                my $sub;
                s/.*::// for my $subname = $autoload;
                $sub = UNIVERSAL::can( $_[0], $subname );
                goto &$sub if $sub;
                $sub = UNIVERSAL::can( $_[0], 'AUTOLOAD' );
                if ($sub) {
                    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
                    return $_[0]->$subname( @_[ 1 .. $#_ ] );
                }
            }
            require Carp;
            local $Carp::CarpLevel = 1;
            Carp::croak("Undefined procedure $autoload called");
        };
    }
}
sub set_autouse{
    while (@_) {
		if ($_[0]=~m/\n/){
			push @_, split " ", $_[0];
			next;
		}
        my ( $module, $param ) = split "=", $_[0], 2;

        my $state = $autouse{ $module };
        if ( ! $state ){
            $state = $autouse{ $module } = {};
            push @autouse, $module;
            set_autoload( $module );
        }
        if ($param) {
            my @all_import = split ",",        $param || '';
            my @var_import = grep m/^[%\@\$]/, @all_import;
            my @sub_import = grep m/^\w/,      @all_import;
			if ( @var_import ){
				$state->{var} = \@var_import;
			}
			if (@sub_import){
				$state->{sub} = \@sub_import;
			}
        }
    }
	continue {
		shift @_;
	}
}
sub clean_namespace {
    my $caller = caller;
    if (ref $_[0]){
        $caller = ${ shift() }[0];
    }
    return 1 if caller eq __PACKAGE__;
    my $x = delete $clean_namespace{ $caller };
    my @x;
    @x = keys %$x if $x;
    push @x, 'clean_namespace';
    push @x, @_;

    for (@x) {
        next unless m/^\w+\z/;
        delete ${ $caller . '::' }{$_};
    }
    'yes!';
}
sub unimport{
	    $^H ^= $^H & 0x00000002;
}
# load site define options
# Prevent Real::Handy loading twice
$INC{'Real/Handy.pm'} ||= 'S';
require_config((caller)[1]) if ! $SKIP_CONFIG;
1;
