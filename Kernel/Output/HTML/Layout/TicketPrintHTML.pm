# --
# Copyright (C) 2017 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::TicketPrintHTML;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub PrintHeader {
    my ( $Self, %Param ) = @_;

    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $LanguageObject = $Kernel::OM->Get('Kernel::Language');
    my $TimeObject     = $Kernel::OM->Get('Kernel::System::Time');

    # unless explicitly specified, we set the header width
    $Param{Width} ||= 640;

    # fix IE bug if in filename is the word attachment
    my $File = $Param{Filename} || $Self->{Action} || 'unknown';
    if ( $Self->{BrowserBreakDispositionHeader} ) {
        $File =~ s/attachment/bttachment/gi;
    }

    # set file name for "save page as"
    $Param{ContentDisposition} = "filename=\"$File.html\"";

    # area and title
    if ( !$Param{Area} ) {
        $Param{Area} = $ConfigObject->Get('Frontend::Module')->{ $Self->{Action} }->{NavBarName}
            || '';
    }
    if ( !$Param{Title} ) {
        $Param{Title} = $ConfigObject->Get('Frontend::Module')->{ $Self->{Action} }->{Title}
            || '';
    }
    for my $Word (qw(Area Title Value)) {
        if ( $Param{$Word} ) {
            $Param{TitleArea} .= ' - ' . $LanguageObject->Translate( $Param{$Word} );
        }
    }

    # set rtl if needed
    if ( $Self->{TextDirection} && $Self->{TextDirection} eq 'rtl' ) {
        $Param{BodyClass} = 'RTL';
    }

    $Self->{DateTimeString} = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $TimeObject->SystemTime()
    );

    my $Output = $Self->Output(
        TemplateFile => 'PrintHeader',
        Data         => \%Param
    );

    # remove the version tag from the header if configured
    $Self->_DisableBannerCheck( OutputRef => \$Output );

    # create & return output
    return $Output;
}

sub PrintFooter {
    my ( $Self, %Param ) = @_;

    $Param{Host} = $Self->Ascii2Html( Text => $ENV{SERVER_NAME} . $ENV{REQUEST_URI} );
    $Param{Host} =~ s/&amp;/&/ig;

    # create & return output
    return $Self->Output(
        TemplateFile => 'PrintFooter',
        Data         => \%Param
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
