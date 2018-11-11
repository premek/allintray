#!/usr/bin/env perl

    ##   #  #  #         #                  
   #  #  #  #     ###   ####  ###   ###   #  #  
   ####  #  #  #  #  #   #    #    #  #   # #  
   #  #  #  #  #  #  #   ###  #     ###    #   
                                         ##    
##################################################
#                                                #
#                  ALLINTRAY                     #
#          Date/time, CPU/RAM usage,             #
#       network traffic, volume control          #
#                                                #
##################################################
#                                                #
#   Copyright (c) 2008 Premek Vyhnal             #
#   <premysl.vyhnal gmail.com>                   #
#                                                #
#   Used code:                                   #
#    - volwheel.pl                               #
#       - thanks to Olivier Duclos - oliwer.net  #
#    - gkrellm-bfm plugin                        #
#                                                #
##################################################

# This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.  
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.  
# You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


# TODO: 
#	datum: vbox do dvou radku datum cas (jak zmensit pismo?)
#
#	jak znazornit traffic (jak zjistit maximum)
#
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
# Gtk2::TrayIcon (debian: libgtk2-trayicon-perl)
# 
# ##################
#
# funguje v trayeru


use warnings;									
use Gtk2 '-init';
use Gtk2::TrayIcon;

# argumenty z prikazovy radky:
$delay = shift (@ARGV) || 1000; # refresh rate (ms)
$rxmax = shift (@ARGV) || 100;	# max download (kBps)
$txmax = shift (@ARGV) || 40;	# max upload (kBps)


$MIXER = "alsamixergui";
$MIXER = "xterm -e 'alsamixer'";
$MIXER = "pavucontrol";
$PROCMAN = "xterm -e 'htop'";
#$PROCMAN = "gtaskmanager";
$CAL1 = "xmessage \"`ccal`\""; # nebo gcal
$CAL2 = "xmessage \"`ccal ".((localtime(time))[5] + 1900)."`\"";
$MEM = "xmessage \"`free`\"";


$PROCSTAT = "/proc/stat";
$PROCNET = "/proc/net/dev";


%labels = (
		tx=>'t',
		rx=>'r',
		r=>'R',
		c=>'C',
		vm=>'m',
		);
=long labels:
%labels = (
		tx=>'Upload',
		rx=>'Download',
		r=>'RAM',
		c=>'CPU',
		vm=>'Master',
		);
=cut




$tray = Gtk2::TrayIcon->new("allintray");
$eventbox = Gtk2::EventBox->new;
$tooltip= Gtk2::Tooltips->new;
$hbox = Gtk2::HBox->new(0,0);
#$vbox = Gtk2::VBox->new(0,0);
#$dlabel = Gtk2::Label->new("A");
$tlabel = Gtk2::Label->new;



@bars = sort keys %labels;

foreach (@bars) {
	$bar{$_} = Gtk2::ProgressBar->new;
	$bar{$_}->set_orientation('bottom-to-top');
	$bar{$_}->set_text($labels{$_});
	$bar{$_}->set_size_request(17, -1);
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
$eventbox{r}->signal_connect( 'button_release_event', \&r_click );
$eventbox{c}->signal_connect( 'button_release_event', \&c_click );
$eventbox{t}->signal_connect( 'button_release_event', \&t_click );

$tray->show_all;


open(STAT,$PROCSTAT);
open(NET,$PROCNET);



&update;

Glib::Timeout->add($delay, \&update);
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
	&mute ("vm") if (2 eq $event->button);
}

sub vm_scroll {
	($check, $event) = @_;
	&volup ("Master") if ("up" eq $event->direction);
	&voldown ("Master") if ("down" eq $event->direction);
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

sub launchMixer { exec $MIXER unless fork; }
sub volup { system "amixer -Dpulse set $_[0] 5%+ &> /dev/null"; }
sub voldown { system "amixer -Dpulse  set $_[0] 5%- &> /dev/null"; }
sub mute {
	if($bar{$_[0]}->get_text eq "x"){
		$bar{$_[0]}->set_text($was{$_[0]});
	} else {
		$was{$_[0]}=$bar{$_[0]}->get_text;
		$bar{$_[0]}->set_text("x");
	}
	system "amixer -Dpulse set ".($_[0]eq"vm" ? "Master":"PCM")." toggle> /dev/null";
}

sub popup {
	$item_factory = Gtk2::ItemFactory->new("Gtk2::Menu", '<main>', undef);
	$popup_menu = $item_factory->get_widget('<main>');
	@menu_items = (
			{ path => '/Suspend',     item_type => '<Item>', callback => sub {`systemctl suspend`}},
			{ path => '/Exit',        item_type => '<Item>', callback => \&out}
			);

	$item_factory->create_items(undef, @menu_items);
	$popup_menu->show_all;
	$popup_menu->popup(undef, undef, undef, undef, 0, 0);
}




###########################################################################################

sub cpu {
	seek STAT,0,0;
	<STAT> =~ m/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+).*$/;

	$load = $1+$2+$3;
	$total = $load+$4+$5+$6+$7;

	unless (defined $lasttotal){ $ret=0; }
	elsif (($total - $lasttotal) <= 0){ $ret=100; } # bez tohohle to obcas zdechne ;)
	else { $ret = int((100 * ($load - $lastload))/($total - $lasttotal)); }

	($lastload, $lasttotal) = ($load,$total);
	return $ret;
}

sub net { # return (Receive,Transmit) in kBps
	seek NET,0,0;
	($rx, $tx) = (grep(/^\s*enp0s25/,<NET>))[0] =~ m/enp0s25:\s*(\d+)\s+(?:\d+\s+){7}(\d+)/;
	not defined $lastrx and @ret = (0,0) or @ret = (int(($rx-$lastrx)/1024/($delay/1000)), int(($tx-$lasttx)/1024/($delay/1000)));
	($lastrx, $lasttx) = ($rx, $tx);
	return (@ret);
}


sub mem {
	`free` =~ m/Mem:\s*(\d+)\s+(\d+)/ms;
	return 100*$2/$1;
}

sub vol {
	$_ = `amixer -D pulse sget Master`;
	s/\n\s+/ /g;
	($vol) = /.*\[(\d+)%\]/;
	return $vol;
}


sub update {
	$mem=&mem;
	$cpu=&cpu;
	$mvol = &vol;
	($nrx, $ntx) = &net;
	($second, $minute,$hour,$day,$month,$year) = (localtime)[0 .. 5]; $year+=1900; $month++;

	$bar{rx}->set_fraction($nrx/$rxmax>1?1:$nrx/$rxmax);
	$bar{tx}->set_fraction($ntx/$txmax>1?1:$ntx/$txmax);
	$bar{r}->set_fraction($mem/100);
	$bar{c}->set_fraction($cpu/100);
	$bar{vm}->set_fraction($mvol/100);

	$tooltip->set_tip($tray,
			sprintf("%d. %d. %d\n%d:%02d:%02d\n\nRAM: %d%%\nCPU: %d%%\nUp: %d kB/s\nDown: %d kB/s\nVol: %d%%",
				$day,$month,$year,$hour,$minute,$second,$mem,$cpu,$ntx,$nrx,$mvol));
	$tlabel->set_text(sprintf(" %d:%02d " , $hour,$minute));
	return 1;
}


############################
sub out {
	close(STAT);
	close(NET);
	Gtk2->main_quit;
}
