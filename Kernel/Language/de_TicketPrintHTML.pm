# --
# Copyright (C) 2018 Perl-Services.de, http://perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_TicketPrintHTML;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    my $Lang = $Self->{Translation} || {};

    $Lang->{'Print (HTML)'}             = 'Drucken (HTML)';
    $Lang->{'Print this ticket (HTML)'} = 'Dieses Ticket drucken (HTML)';
}

1;
