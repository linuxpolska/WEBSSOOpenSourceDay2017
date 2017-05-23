## WARSZTATY WEBSSO Open Source Day 2017

To jest repozytorium przechowujące konfigurację środowiska warsztatowego
na potrzeby warsztatów WEBSSO prowadzonych w trakcie Open Source Day 2017

#### Dotyczy osób, które miały problem z konfiguracją środowiska na Windowsie
Jeśli otrzymywałeś/aś błąd:
```sh
set: usage: set [-abefhkmnptuvxBCHP] [-o option -name] [--] [arg ...]
This SSH command responded with a non-zero exit status. Vagrant
assumes that this means the command faild. The output for this command should be
in the log above. Please read the output to determine what went wrong.
```
Poprawka została wgrana do repozytorium, aby usunać problem wykonaj w linii polececeń poniższe komendy:
```sh
vagrant destroy -f
git fetch --all
git reset --hard origin/master
git pull -f origin master
```
Problem był spowodowany domyślną konfiguracją klienta Git pod Windows. Domyślna konfiguracja dokonuje konwersji
znaków końca linii podczas pobierania plików z repozytorium. Zmiany te powodowały nie wykonywanie się skryptów
na maszynach wirtualnych i niszczyły de fakto pliki konfiguracyjne. Do repozytorium wgrano poprawkę, która powoduje
blokowanie tej funkcji dla wszystkich plików. Powyższe komendy wymuszają ponowne pobranie wszystkich plików w repozytorium
tym razem w postaci nie zmienionej. Osoby, które sklonowały repozytorium przed wgraniem do niego poprawki
 powinny wykonać te komendy, osoby które nie klonowały jeszcze repozytorium nie muszą wystarczy, że sklonują repozytorium.
 Konwersja już nie powinna następować bez względu na to jak skonfigurowany jest klient Git.

#### Wymagania minimalne środowiska

W celu przeprowadzenia ćwiczeń warsztatowych należy posiadać komputer, który
pozwoli na uruchomienie obok siebie 3 jednocześnie pracujących maszyn wirtualnych
o łącznej ilości pamięci ram poniżej 2.5 GB. Powinno to zapewnić poprawną pracę
środowiska na systemie fizycznym wyposażonym w 4GB pamięci RAM. Nie zaleca się 
prób instalacji środowiska na systemach wyposżonych w mniejszą ilośc pamięci RAM.
Wymagany jest 64 bitowy system operacyjny i komputer z procesorem kompatybilnym z systemami CentOs 7.2.
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
Podczas budowania środowiska możesz zosać zapytany o hasło lokalnego lub
administracyjnego użytkownika celem dopisania nazw instalowanych hostów do
lokalnego systemu wyszukiwania nazw (np. pliku /etc/hosts). W takim przypadku
wprowadź wymagane hasło.
Osoby wyposażone w komputery o ilości pamięci RAM nie przekraczającej 8GB
powinny zbudować środowisko poprzez wydanie komend:
```sh
vagrant up 389ds.websso.linuxpolska.pl cas.websso.linuxpolska.pl appcas.websso.linuxpolska.pl
```
Po zakończeniu budowy środowiska 3 pierwszych maszyn należy zamknąć 2 z nich
i dokonać zbudowania pozostałych maszyn wydając komendy:
(potwierdzając wykonanie komend poprzez Y):
```sh
vagrant halt cas.websso.linuxpolska.pl appcas.websso.linuxpolska.pl
vagrant up keycloak.websso.linuxpolska.pl appkeycloak.websso.linuxpolska.pl
```

Należy pamiętać, że uruchomienie środowiska po jego uprzednim zbudowaniu
zajmie znacząco mniej czasu.

##### Testowanie poprawności instalacji środowiska

W celu przetestowania poprwaności instalacji środowiska należy sprawdzić czy wszystkie
jego znaczące składniki wywołują się w przegląderce, w tym celu po zbudowaniu środowiska
wprowadź w przeglądarce wszystkie podane poniżej adresy:
Uwaga!!! Środowisko posiada certyfikaty typu self signed wymagające ich akceptacji w przeglądarce:
Jako alternatywę dla akceptacji każdego certyfikatu z osobna można zaimportować do przeglądarki
certyfikaty z podkatalogu **tmp** (wszystkie pliki zakończone rozszeżeniem *crt*).
**Witryny do sprawdzenia:**
* https://cas.websso.linuxpolska.pl/auth - Strona logowania Apereo CAS
* https://cas.websso.linuxpolska.pl/auth/status/dashboard - Strona logowania do strony zarządzania CAS
* https://cas.websso.linuxpolska.pl/cas-management - Strona logowania do systemu zarządzania serwisami CAS
* https://appcas.websso.linuxpolska.pl/wordpress - Strona systemu Wordpress via CAS
* https://appcas.websso.linuxpolska.pl/liferay - Strona portalu Liferay via CAS
* https://keycloak.websso.linuxpolska.pl - Strona główna serwera KeyCloak
* https://appkeycloak.websso.linuxpolska.pl/wordpress - Strona systemu Wordpress via KeyCloak
* https://appkeycloak.websso.linuxpolska.pl/liferay - Strona systemu Liferay via KeyCloak

W przypadku wystąpienia problemów z instalacją prosimy o zgłaszanie błedów korzystając z funkcji ISSUES.
Przed zgłoszniem zachęcamy do sprawdzenia czy aktualizacja składników (VirtualBox, Vagrant) do najnowszych wersji
nie spowoduje zniknięcia problemów.

##### Scenariusze sukcesu

Potwierdzono pełną poprawną instlację środowiska w następującyh systemach:
* Fedora Linux 25, Vagrant: 1.8.5, VirtualBox 5.1.22 (dopisywania wpisów do /etc/hosts wymaga jednokrotnego podniesienia uprawnień - podania hasła)
* Gentoo Linux Base System Relaease 2.3, Vagrant 1.9.3, VirtualBox 5.1.22 (dopisywania wpisów do /etc/hosts wymaga jednokrotnego podniesienia uprawnień - podania hasła)
* Linux Mint 18.1, Vagrant 1.9.4 (wymagał ręcznej aktualizacji), VirtualBox 5.0.36 (dopisywania wpisów do /etc/hosts wymaga jednokrotnego podniesienia uprawnień - podania hasła)
* Windows 10, Vagrant 1.8.6, VirtualBox 5.1.10 (proces instalacji wymaga potwierdzania podwyższania uprawnień w trakcie budowy każdej z maszyn - dopisywanie wpisów do lokalnego systemu wyszukiwania nazw)
* LinuxMint 18.1 ,Vagrant 1.9.3 , VirtualBox 5.1.20 (dopisywania wpisów do /etc/hosts wymaga jednokrotnego podniesienia uprawnień - podania hasła)
* Debian 9.0 Parrot, Vagrant 1.9.5, VirtualBox 5.1.18 (dopisywania wpisów do /etc/hosts wymaga jednokrotnego podniesienia uprawnień - podania hasła)
* Windows 7, Vagrant 1.9.5, VirtualBox 5.1.22 (proces instalacji wymaga potwierdzania podwyższania uprawnień w trakcie budowy każdej z maszyn - dopisywanie wpisów do lokalnego systemu wyszukiwania nazw)

#### Optymalizacja pracy środowiska

Osoby posiadające systemy wyposażone w ilość Ramu przekraczając 8GB zachęca się 
do optymalizacji środowiska pracy poprzez zwiększenie parametrów pracy systemów.
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
