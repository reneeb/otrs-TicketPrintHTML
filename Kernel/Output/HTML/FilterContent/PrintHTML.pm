# --
# Copyright (C) 2018 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterContent::PrintHTML;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Language
    Kernel::Output::HTML::Layout
    Kernel::System::Web::Request
    Kernel::Config
    Kernel::System::Ticket
    Kernel::System::Ticket::Article
    Kernel::System::Log
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LanguageObject = $Kernel::OM->Get('Kernel::Language');
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $JSONObject     = $Kernel::OM->Get('Kernel::System::JSON');
    my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ArticleObject  = $Kernel::OM->Get('Kernel::System::Ticket::Article');

    my $Action = $ParamObject->GetParam( Param => 'Action' );
    return 1 if !$Param{Templates}->{$Action};

    my $Title    = $LanguageObject->Translate('Print (HTML)');
    my $Baselink = $LayoutObject->{Baselink};
    my $TicketID = $ParamObject->GetParam( Param => 'TicketID' );

    my @Articles = $ArticleObject->ArticleList(
        TicketID => $TicketID,
    );

    for my $Article ( @Articles ) {
        my $ArticleID = $Article->{ArticleID};

        my $Link = qq~
            <li class="ArticleNote">
                <a href="${Baselink}Action=AgentTicketPrintHTML;TicketID=$TicketID;ArticleID=$ArticleID" title="$Title" class="AsPopup Popup_Type_TicketAction" target="print">$Title</a>
            </li>
        ~;

        ${ $Param{Data} } =~ s{
            <a \s+ name="Article $ArticleID" .*?
            <ul \s+ class="Actions"> \K
        }{
            $Link
        }xms;
    }

    return 1;
}

1;
