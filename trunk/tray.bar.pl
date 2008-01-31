#!/usr/bin/env perl

        ##  # #  #       #                                                        
       #  # # #    ###  #### ###  ###  #  #                                       
       #### # #  # #  #  #   #   #  #  # #                                       
       #  # # #  # #  #  ### #    ###   #                                        
                                      ##  
##################################################
#                                                #
#              A L L I N T R A Y                 #
#      Clock, CPU/RAM usage, volume control      #
#                                                #
##################################################
#  Premek Vyhnal <premysl.vyhnal gmail.com>      #
#                                                #
#  Used code:                                    #
#   - volwheel.pl                                #
#      - thanks to Olivier Duclos - oliwer.net   #
#   - gkrellm-bfm plugin                         #
##################################################

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version. 
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details. 
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 
# USA



# todo: 
#	datum: vbox do dvou radku datum cas (neumim zmensit pismo)
#
#	jak znazornit traffic (bfm?)
#
#	šířka barů
#
#  vypisovat mute
#

# ##################
# co to potřebuje:
# ##################
# amixer
# + to co se nastaví na kliknutí:
#     xmessage
#     alsamixergui (alsamixer v xtermu)
#     ccal (gcal)
# ##################
# /proc/stat
# /proc/net/dev
# ##################
# perl
# Gtk2
# Gtk2::TrayIcon
# ##################
#
# funguje v trayeru


use warnings;									
use Gtk2 '-init';
use Gtk2::TrayIcon;


$DELAY = shift (@ARGV) || 1000;

$MIXER = "alsamixergui";
$MIXER = "xterm -e 'alsamixer'";
$PROCMAN = "xterm -e 'htop'";
$PROCMAN = "gtaskmanager";
$CAL1 = "xmessage \"`ccal`\"";
$CAL2 = "xmessage \"`ccal ".((localtime(time))[5] + 1900)."`\"";
$MEM = "xmessage \"`free`\"";



$PROCSTAT = "/proc/stat";
$PROCNET = "/proc/net/dev";

$tray = Gtk2::TrayIcon->new("allintray");
$eventbox = Gtk2::EventBox->new;
$tooltip= Gtk2::Tooltips->new;
$hbox = Gtk2::HBox->new(0,0);
#$vbox = Gtk2::VBox->new(0,0);
#$dlabel = Gtk2::Label->new("A");
$tlabel = Gtk2::Label->new;


%labels = (
		tx=>'tx',
		rx=>'rx',
		r=>'R',
		c=>'C',
		vm=>'m',
		vp=>'p',
		);



=comm
%labels = (
		tx=>'Upload',
		rx=>'Download',
		r=>'RAM',
		c=>'CPU',
		vm=>'Master',
		vp=>'PCM',
		);
=cut


@bars = sort keys %labels;

foreach (@bars) {
	$bar{$_} = Gtk2::ProgressBar->new;
	$bar{$_}->set_orientation('bottom-to-top');
	$bar{$_}->set_text($labels{$_});
	$eventbox{$_} = Gtk2::EventBox->new;
	$hbox->add($eventbox{$_});
	$eventbox{$_}->add($bar{$_});
}
#$hbox->add($vbox);
#$vbox->add($tlabel);
#$vbox->add($dlabel);

$eventbox{t} = Gtk2::EventBox->new;
$hbox->add($eventbox{t});
$eventbox{t}->add($tlabel);


$tray->add($eventbox);
$eventbox->add($hbox);

$eventbox->signal_connect( 'button_release_event', \&click );


$eventbox{vm}->signal_connect( 'button_release_event', \&vm_click );
$eventbox{vm}->signal_connect( 'scroll_event', \&vm_scroll);
$eventbox{vp}->signal_connect( 'button_release_event', \&vp_click );
$eventbox{vp}->signal_connect( 'scroll_event', \&vp_scroll);
$eventbox{r}->signal_connect( 'button_release_event', \&r_click );
$eventbox{c}->signal_connect( 'button_release_event', \&c_click );
$eventbox{t}->signal_connect( 'button_release_event', \&t_click );

$tray->show_all;


open(STAT,$PROCSTAT);
open(NET,$PROCNET);

$lastload=0;
$lasttotal=0;
$lastrx=0;
$lasttx=0;




&update;

Glib::Timeout->add($DELAY, \&update);
Gtk2->main();



##########################################################################

#global click
sub click {
	($check, $event) = @_;
	&popup if (3 eq $event->button)
}


#local clicks

sub vm_click {
	($check, $event) = @_;
	&launchMixer if (1 eq $event->button);
	&mute ("Master") if (2 eq $event->button);
}

sub vm_scroll {
	($check, $event) = @_;
	&volup ("Master") if ("up" eq $event->direction);
	&voldown ("Master") if ("down" eq $event->direction);
	&update;
}

sub vp_click {
	($check, $event) = @_;
	&launchMixer if (1 eq $event->button);
	&mute ("PCM") if (2 eq $event->button);
}

sub vp_scroll {
	($check, $event) = @_;
	&volup ("PCM") if ("up" eq $event->direction);
	&voldown ("PCM") if ("down" eq $event->direction);
	&update;
}

sub t_click {
	($check, $event) = @_;
	if (1 eq $event->button) { exec $CAL1 unless fork; }
	if (2 eq $event->button) { exec $CAL2 unless fork; }
}

sub r_click {
	($check, $event) = @_;
	if (1 eq $event->button) { exec $MEM unless fork; }
}
sub c_click {
	($check, $event) = @_;
	if (1 eq $event->button) { exec $PROCMAN unless fork; }
}



##########################################################################

sub volup { system "amixer set $_[0] 5%+ &> /dev/null"; }
sub voldown { system "amixer set $_[0] 5%- &> /dev/null"; }
sub mute { system "amixer set $_[0] toggle> /dev/null"; }
sub launchMixer { exec $MIXER unless fork; }


sub popup {
	$item_factory = Gtk2::ItemFactory->new("Gtk2::Menu", '<main>', undef);
	$popup_menu = $item_factory->get_widget('<main>');
	@menu_items = (
            { path => '/About',       item_type => '<Item>', callback => \&about_dialog},
			{ path => '/Exit',        item_type => '<Item>', callback => \&out}
			);

	$item_factory->create_items(undef, @menu_items);
	$popup_menu->show_all;
	$popup_menu->popup(undef, undef, undef, undef, 0, 0);
}

sub about_dialog {
    $about = Gtk2::AboutDialog->new;
    $about->set_name("VolWheel");
    $about->set_version($VERSION);
    $about->set_copyright("Copyright (c) Olivier Duclos 2007");
    $about->set_comments("Set volume with the mousewheel. Sweet!");
    $about->set_website("oliwer\@hedinux.org");
#    $about->set_logo($pixbuf);
    $about->run;
    $about->destroy;
}



###########################################################################################

sub cpu {
	seek STAT,0,0;
	<STAT> =~ m/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+).*$/;

	$load = $1+$2+$3;
	$total = $load+$4+$5+$6+$7;

	if ($lasttotal==0){ $ret=0; }
	elsif (($total - $lasttotal) <= 0){ $ret=100; } # bez tohohle to obcas zdechne
	else { $ret = int((100 * ($load - $lastload))/($total - $lasttotal)); }

	($lastload, $lasttotal) = ($load,$total);
	return $ret;
}

sub net { # ret (rx,tx);
	seek NET,0,0;
	@a=<NET>;
	@a=grep(/^\s*eth0/,@a);
	($rx, $tx) = $a[0] =~ m/eth0:\s*(\d+)\s+(?:\d+\s+){7}(\d+)/;
print $rx;
	@ret = (int(($rx-$lastrx)/1024/($DELAY/1000)),
			int(($tx-$lasttx)/1024/($DELAY/1000)));
	@ret = (0,0) if ($lastrx==0);
	($lastrx, $lasttx) = ($rx, $tx);
	return (@ret);
}


sub mem {
	`free` =~ m/Mem:\s*(\d+).*\n.*cache:\s+(\d+)/;
	return 100*$2/$1;
}




sub update {
	$mem=&mem;
	$cpu=&cpu;
	$_ = `amixer`;
	s/\n\s+/ /g;
	($mvol) = /'Master'.*\[(\d+)%\]/;
	($pvol) = /'PCM'.*\[(\d+)%\]/;
	@cas=localtime(time);
	($nrx, $ntx) = &net;
	$nrxb = $nrx/100>1?1:$nrx/100;
	$ntxb = $ntx/40>1?1:$ntx/40;

	$bar{rx}->set_fraction($nrxb);
	$bar{tx}->set_fraction($ntxb);
	$bar{r}->set_fraction($mem/100);
	$bar{c}->set_fraction($cpu/100);
	$bar{vm}->set_fraction($mvol/100);
	$bar{vp}->set_fraction($pvol/100);

	$tooltip->set_tip($tray,
			sprintf("%d. %d. %d\n%d:%02d\n\nRAM: %d%%\nCPU: %d%%\n\nNet:\nUPL: %d kB/s\nDWN: %d kB/s\n\nVol:\nMaster: %d%%\nPCM: %d%%",
				$cas[3],$cas[4]+1,$cas[5]+1900,$cas[2],$cas[1],$mem,$cpu,$ntx,$nrx,$mvol,$pvol));
	$tlabel->set_text(sprintf(" %d:%02d " , $cas[2],$cas[1]));
#	$dlabel->set_text(sprintf(" %d. %d. %d " , $cas[3],$cas[4]+1,$cas[5]+1900));

	return 1;
}


############################
sub out {
	close(STAT);
	close(NET);
	Gtk2->main_quit;
}
