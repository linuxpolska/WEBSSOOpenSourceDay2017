## WARSZTATY WEBSSO Open Source Day 2017

To jest repozytorium przechowujące konfigurację środowiska warsztatowego
na potrzeby warsztatów WEBSSO prowadzonych w trakcie Open Source Day 2017

#### Bardzo Ważne!!!

Środowisko powinno zostać sklonowane i zainstalowane co najmniej 24 przed
rozpoczęciem warsztatów. Środowisko składa się ze składników, których
automatyczne pobranie i instalacja oraz wstępna konfiguracja zajmuje zdecydowanie
więcej czasu niż sam czas trwania ćwiczeń przewidzianych do przeprowadzania na
warsztatach. Serdecznie prosimy o nie ignorowanie tej informacji.
Instrukcje dotyczące wstępnej instalacji i konfiguracji środowiska znajdują się
poniżej.

#### Wymagania minimalne środowiska

W celu przeprowadzenia ćwiczeń warsztatowych należy posiadać komputer, który
pozwoli na uruchomienie obok siebie 3 jednocześnie pracujących maszyn wirtualnych
o łącznej ilości pamięci ram poniżej 2.5 GB. Powinno to zapewnić poprawną pracę
środowiska na systemie fizycznym wyposażonym w 4GB pamięci RAM. Nie zaleca się 
prób instalacji środowiska na systemach wyposżonych w mniejszą ilośc pamięci RAM.
Więcej informacji dotyczących wydajności pracy środowiska można znaleźć w sekcji
 Optymalizacja pracy środowiska.

#### Pobranie i instalacja środowiska

Przed przystąpienieniem do uruchomienia środowiska użytkownik powinien
zainstalować na swoim komputerze następujące składniki oprogramowania:
* `Git` - https://git-scm.com/
* `VirtualBox` - https://www.virtualbox.org/
* `Vagrant` - http://vagrantup.com

Zaleca się instalację wyżej wymienionych składników poprzez mechanizmy systemu
operacyjnego z jakiego korzysta użytownik.

Po zainstalowaniu składników należy dokonać sklonowania repozytorium git
poprzez wydanie komendy:
```sh
git clone https://github.com/linuxpolska/WEBSSOOpenSourceDay2017.git
```

Po zakończeniu klonowania należy wejść do katalogu przechowującego lokalnie
sklonowane repozytorium i dokonać instalacji niezbędnych wtyczek systemu VAGRANT
wydając poniższ komendy:

```sh
vagrant plugin install vagrant-hostmanager
vagrant plugin install vagrant-vbguest
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-timezone
```

Po zainstalowaniu wtyczek można dokonać wstępnego zbudowania środowiska. Jeśli
Twój komputer posiada nie mniej niż 8GB ram zbuduj i wstępnie skonfiguruj
środwisko wydając polecenie:
```sh
vagrant up
```
Spowoduje to wstępną konfigurację środowiska dla wszystkich maszyn wirtualnych.

Osoby wyposażone w komputery o ilości pamięci RAM nie przekraczającej 8GB
powinny zbudować środowisko poprzez wydanie komend:
```sh
vagrant up 389ds.websso.linuxpolska.pl cas.websso.linuxpolska.pl appcas.websso.linuxpolska.pl
```
Po zakończeniu budowy środowiska 3 pierwszych maszyn należy zamknąć 2 z nich
i dokonać zbudowania pozostałych maszyn wydając komendy:
(potwierdzając komendy poprzez Y):
```sh
vagrant halt cas.websso.linuxpolska.pl appcas.websso.linuxpolska.pl
vagrant up keycloak.websso.linuxpolska.pl appkeycloak.websso.linuxpolska.pl
```

Należy pamiętać, że uruchomienie środowiska po jego uprzednim zbudowaniu
zajmie znacząco mniej czasu.

##### Scenariusze sukcesu

Potwierdzono pełną poprawną instlację środowiska w następującyh systemach:
* Fedora Linux 25:, Vagrant: 1.8.5, VirtualBox 5.1.22
* Gentoo Linux Base System Relaease 2.3, Vagrant 1.9.3, VirtualBox 5.1.22

#### Optymalizacja pracy środowiska

Osoby posiadające systemy wyposażone w ilość Ramu przekraczając 8GB zachęca się 
do optymalizacji środowisak pracy poprzez zwiększenie parametrów pracy systemów.
Optymalizacji należy doknać przed wstępną konfiguracją środowiska.  
W tym celu po sklonowaniu śrowiska pracy systemu należy poddać edycji plik
node.json i dwukrotnie zwiększyć parametr: ":memory":  dla wszystkich maszyn
wirtualnych:
```sh
np.: z 512 do 1024
```
Zapewni to szybszą pracę całości środiwska (szybrszą inicjalizację aplikacji).
Jeśli optymalizacji dokonano po wstępnym zbudowaniu środowiska (wydaniu komendy vagrant up)
można dokonać ponownej budowy środowiska poprzez wydanie komend:
```sh
vagrant destroy
vagrant up
```

#### Składniki środowiska
W trakcie budowania środowiska pobrane zostaną wszystkie jego znaczące składniki.
Elementy te zostaną zapisane w podkatalogu tmp: zaleca się by nie kasować jego
zawartości przed przebudową środowiska.  Skasowanie zawartości katalogu tmp
spowoduje pobranie składników od początku i znacznie przedłuży czas budowania
środowiska.
W skład środowiska wchodzą lokalne serwery wirtualne:
* `389ds.websso.linuxpolska.pl` - Serwer usługi katalowegj LDAP (realm uwierzytelnienia)
* `cas.websso.linuxpolska.pl` - Serwer systemu SSO Apereo CAS
* `appcas.websso.linuxpolska.pl` - Serwer aplikacji dla integracji z CAS
* `keycloak.websso.linuxpolska.pl` - Serwer systemu SSO KeyCloak
* `appkeycloak.websso.linuxpolska.pl` - Serwer aplikacji dla integracji z KeyCloak

#### Przydatne komendy do zarządania środowiskiem maszyn wirtuanym
Wykorzyztanie opcji <maszyna> jest opcjonalne w większości przydaków
* `vagrant up <machine>`
* `vagrant reload <machine>`
* `vagrant destroy -f <machine> && vagrant up <machine>`
* `vagrant status <machine>`
* `vagrant ssh <machine>`
* `vagrant global-status`

#### Logi przydatne do debugowania funkcjonalności środiwiska
Niektóre logi będą wymagały zalogowani na konto roota lub dostępu przez sudo
* `sudo tail -50 /var/log/syslog`
* `tail -50 ~/VirtualBox\ VMs/<machine>/Logs/VBox.log`

#### Hasło rota dla wszystkich maszyn wirtualnych
`vagrant`
