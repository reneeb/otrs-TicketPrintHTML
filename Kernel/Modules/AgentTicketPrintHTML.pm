# --
# Copyright (C) 2017 Perl-Services.de, http://perl-services.de	
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketPrintHTML;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

use List::Util qw(first);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get config settings


    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LinkObject         = $Kernel::OM->Get('Kernel::System::LinkObject');

    my $Output;
    my $QueueID   = $TicketObject->TicketQueueID( TicketID => $Self->{TicketID} );
    my $ArticleID = $ParamObject->GetParam( Param => 'ArticleID' );

    $Self->{ZoomExpandSort}     = $ConfigObject->Get('Ticket::Frontend::ZoomExpandSort');
    $Self->{DynamicFieldFilter} = $ConfigObject->Get("Ticket::Frontend::AgentTicketPrint")->{DynamicField};

    # check needed stuff
    if ( !$Self->{TicketID} || !$QueueID ) {
        return $LayoutObject->ErrorScreen( Message => 'Need TicketID!' );
    }

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    return $LayoutObject->NoPermission( WithHeader => 'yes' ) if !$Access;

    # get ACL restrictions
    my %PossibleActions = ( 1 => $Self->{Action} );

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();

    # check if ACL restrictions exist
    if ( $ACL || IsHashRefWithData( \%AclAction ) ) {

        my %AclActionLookup = reverse %AclAction;

        # show error screen if ACL prohibits this action
        if ( !$AclActionLookup{ $Self->{Action} } ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }

    # get linked objects
    my $LinkListWithData = $LinkObject->LinkListWithData(
        Object           => 'Ticket',
        Key              => $Self->{TicketID},
        State            => 'Valid',
        UserID           => $Self->{UserID},
        ObjectParameters => {
            Ticket => {
                IgnoreLinkedTicketStateTypes => 1,
            },
        },
    );

    # get link type list
    my %LinkTypeList = $LinkObject->TypeList(
        UserID => $Self->{UserID},
    );

    # get the link data
    my %LinkData;
    if ( $LinkListWithData && ref $LinkListWithData eq 'HASH' && %{$LinkListWithData} ) {
        %LinkData = $LayoutObject->LinkObjectTableCreate(
            LinkListWithData => $LinkListWithData,
            ViewMode         => 'SimpleRaw',
        );
    }

    # get content
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );
    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID                   => $Self->{TicketID},
        StripPlainBodyAsAttachment => 1,
        UserID                     => $Self->{UserID},
        DynamicFields              => 0,
    );

    # check if only one article need printed
    if ($ArticleID) {

        ARTICLE:
        for my $Article (@ArticleBox) {
            if ( $Article->{ArticleID} == $ArticleID ) {
                @ArticleBox = ($Article);
                last ARTICLE;
            }
        }
    }

    # show total accounted time if feature is active:
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        $Ticket{TicketTimeUnits} = $TicketObject->TicketAccountedTimeGet(
            TicketID => $Ticket{TicketID},
        );
    }

    # user info
    my %UserInfo = $UserObject->GetUserData(
        User => $Ticket{Owner},
    );

    # responsible info
    my %ResponsibleInfo;
    if ( $ConfigObject->Get('Ticket::Responsible') && $Ticket{Responsible} ) {
        %ResponsibleInfo = $UserObject->GetUserData(
            User => $Ticket{Responsible},
        );
    }

    # customer info
    my %CustomerData;
    if ( $Ticket{CustomerUserID} ) {
        %CustomerData = $CustomerUserObject->CustomerUserDataGet(
            User => $Ticket{CustomerUserID},
        );
    }

    # do some html quoting
    $Ticket{Age} = $LayoutObject->CustomerAge(
        Age   => $Ticket{Age},
        Space => ' ',
    );

    if ( $Ticket{UntilTime} ) {
        $Ticket{PendingUntil} = $LayoutObject->CustomerAge(
            Age   => $Ticket{UntilTime},
            Space => ' ',
        );
    }

    # output header
    $Output .= $LayoutObject->PrintHeader( Value => $Ticket{TicketNumber} );

    if (%LinkData) {

        # output link data
        $LayoutObject->Block(
            Name => 'Link',
        );

        for my $LinkTypeLinkDirection ( sort { lc $a cmp lc $b } keys %LinkData ) {

            # investigate link type name
            my @LinkData = split q{::}, $LinkTypeLinkDirection;

            # output link type data
            $LayoutObject->Block(
                Name => 'LinkType',
                Data => {
                    LinkTypeName => $LinkTypeList{ $LinkData[0] }->{ $LinkData[1] . 'Name' },
                },
            );

            # extract object list
            my $ObjectList = $LinkData{$LinkTypeLinkDirection};

            for my $Object ( sort { lc $a cmp lc $b } keys %{$ObjectList} ) {

                for my $Item ( @{ $ObjectList->{$Object} } ) {

                    # output link type data
                    $LayoutObject->Block(
                        Name => 'LinkTypeRow',
                        Data => {
                            LinkStrg => $Item->{Title},
                        },
                    );
                }
            }
        }
    }

    # output customer infos
    if (%CustomerData) {
        $Param{CustomerTable} = $LayoutObject->AgentCustomerViewTable(
            Data => \%CustomerData,
            Max  => 100,
        );
    }

    # show ticket
    $Output .= $Self->_HTMLMask(
        TicketID        => $Self->{TicketID},
        QueueID         => $QueueID,
        ArticleBox      => \@ArticleBox,
        ResponsibleData => \%ResponsibleInfo,
        %Param,
        %UserInfo,
        %Ticket,
    );

    # add footer
    $Output .= $LayoutObject->PrintFooter();

    # return output
    return $Output;
}

sub _HTMLMask {
    my ( $Self, %Param ) = @_;

    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $JSONObject         = $Kernel::OM->Get('Kernel::System::JSON');

    # output responsible, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Responsible') ) {
        my $Responsible = '-';
        if ( $Param{Responsible} ) {
            $Responsible = $Param{Responsible} . ' ('
                . $Param{ResponsibleData}->{UserFirstname} . ' '
                . $Param{ResponsibleData}->{UserLastname} . ')';
        }
        $LayoutObject->Block(
            Name => 'Responsible',
            Data => {
                ResponsibleString => $Responsible,
            },
        );
    }

    # output type, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Type') ) {
        $LayoutObject->Block(
            Name => 'TicketType',
            Data => { %Param, },
        );
    }

    # output service and sla, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Service') ) {
        $LayoutObject->Block(
            Name => 'TicketService',
            Data => {
                Service => $Param{Service} || '-',
                SLA     => $Param{SLA}     || '-',
            },
        );
    }

    # output accounted time
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        $LayoutObject->Block(
            Name => 'AccountedTime',
            Data => {%Param},
        );
    }

    # output pending date
    if ( $Param{PendingUntil} ) {
        $LayoutObject->Block(
            Name => 'PendingUntil',
            Data => {%Param},
        );
    }

    # output first response time
    if ( defined( $Param{FirstResponseTime} ) ) {
        $LayoutObject->Block(
            Name => 'FirstResponseTime',
            Data => {%Param},
        );
    }

    # output update time
    if ( defined( $Param{UpdateTime} ) ) {
        $LayoutObject->Block(
            Name => 'UpdateTime',
            Data => {%Param},
        );
    }

    # output solution time
    if ( defined( $Param{SolutionTime} ) ) {
        $LayoutObject->Block(
            Name => 'SolutionTime',
            Data => {%Param},
        );
    }

    # get the dynamic fields for ticket object
    my $DynamicField = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    # cycle trough the activated Dynamic Fields for ticket object
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $Value = $BackendObject->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{TicketID},
        );

        next DYNAMICFIELD if !$Value;
        next DYNAMICFIELD if $Value eq "";

        # get print string for this dynamic field
        my $ValueStrg = $BackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
            HTMLOutput         => 1,
            ValueMaxChars      => 20,
            LayoutObject       => $LayoutObject,
        );

        my $Label = $DynamicFieldConfig->{Label};

        $LayoutObject->Block(
            Name => 'TicketDynamicField',
            Data => {
                Label => $Label,
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'TicketDynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Label => $Label,
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );
    }

    # build article stuff
    my $SelectedArticleID = $Param{ArticleID} || '';
    my @ArticleBox = @{ $Param{ArticleBox} };

    # get last customer article
    for my $ArticleTmp (@ArticleBox) {
        my %Article = %{$ArticleTmp};

        # get attachment string
        my %AtmIndex = ();
        if ( $Article{Atms} ) {
            %AtmIndex = %{ $Article{Atms} };
        }
        $Param{'Article::ATM'} = '';
        for my $FileID ( sort keys %AtmIndex ) {
            my %File = %{ $AtmIndex{$FileID} };
            $File{Filename} = $LayoutObject->Ascii2Html( Text => $File{Filename} );
            my $DownloadText = $LayoutObject->{LanguageObject}->Translate("Download");
            $Param{'Article::ATM'}
                .= '<a href="' . $LayoutObject->{Baselink} . 'Action=AgentTicketAttachment;'
                . "ArticleID=$Article{ArticleID};FileID=$FileID\" target=\"attachment\" "
                . "title=\"$DownloadText: $File{Filename}\">"
                . "$File{Filename}</a> $File{Filesize}<br/>";
        }

        if ( $Article{ArticleType} eq 'chat-external' || $Article{ArticleType} eq 'chat-internal' )
        {
            $Article{ChatMessages} = $JSONObject->Decode(
                Data => $Article{Body},
            );
            $Article{IsChat} = 1;
        }
        else {

            # check if just a only html email
            my $MimeTypeText = $LayoutObject->CheckMimeType(
                %Param,
                %Article,
                Action => 'AgentTicketZoom',
            );
            if ($MimeTypeText) {
                $Param{TextNote} = $MimeTypeText;
                $Article{Body}   = '';
            }
            else {

                # html quoting
                $Article{Body} = $LayoutObject->Ascii2Html(
                    NewLine => $ConfigObject->Get('DefaultViewNewLine'),
                    Text    => $Article{Body},
                    VMax    => $ConfigObject->Get('DefaultViewLines') || 5000,
                );
            }
        }

        $LayoutObject->Block(
            Name => 'Article',
            Data => { %Param, %Article },
        );

        # do some strips && quoting
        for my $Parameter (qw(From To Cc Subject)) {
            if ( $Article{$Parameter} ) {
                $LayoutObject->Block(
                    Name => 'Row',
                    Data => {
                        Key   => $Parameter,
                        Value => $Article{$Parameter},
                    },
                );
            }
        }

        # show accounted article time
        if ( $ConfigObject->Get('Ticket::ZoomTimeDisplay') ) {
            my $ArticleTime = $TicketObject->ArticleAccountedTimeGet(
                ArticleID => $Article{ArticleID},
            );
            $LayoutObject->Block(
                Name => "Row",
                Data => {
                    Key   => 'Time',
                    Value => $ArticleTime,
                },
            );
        }

        # get the dynamic fields for ticket object
        my $DynamicField = $DynamicFieldObject->DynamicFieldListGet(
            Valid       => 1,
            ObjectType  => ['Article'],
            FieldFilter => $Self->{DynamicFieldFilter} || {},
        );

        # cycle trough the activated Dynamic Fields for ticket object
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$DynamicField} ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $Value = $BackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Article{ArticleID},
            );

            next DYNAMICFIELD if !$Value;
            next DYNAMICFIELD if $Value eq "";

            # get print string for this dynamic field
            my $ValueStrg = $BackendObject->DisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Value,
                HTMLOutput         => 1,
                ValueMaxChars      => 20,
                LayoutObject       => $LayoutObject,
            );

            my $Label = $DynamicFieldConfig->{Label};

            $LayoutObject->Block(
                Name => 'ArticleDynamicField',
                Data => {
                    Label => $Label,
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );

            # example of dynamic fields order customization
            #            $Self->{LayoutObject}->Block(
            #                Name => 'ArticleDynamicField_' . $DynamicFieldConfig->{Name},
            #                Data => {
            #                    Label => $Label,
            #                    Value => $ValueStrg->{Value},
            #                    Title => $ValueStrg->{Title},
            #                },
            #            );
        }
    }

    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketPrintHTML',
        Data         => \%Param,
    );
}

1;
