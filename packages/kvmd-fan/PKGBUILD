pkgname=kvmd-fan
pkgver=0.14
pkgrel=1
pkgdesc="PiKVM - A small fan controller daemon"
url="https://github.com/pikvm/kvmd-fan"
license=(GPL)
arch=(armv6h armv7h aarch64)
depends=(
	libmicrohttpd
	libgpiod
	wiringpi
)
source=(${pkgname}::"git+https://github.com/pikvm/kvmd-fan#commit=v${pkgver}")
md5sums=(SKIP)


build() {
	cd "$srcdir"
	rm -rf $pkgname-build
	cp -r $pkgname $pkgname-build
	cd $pkgname-build
	make CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" $MAKEFLAGS
}

package() {
	cd "$srcdir/$pkgname-build"
	make CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" DESTDIR="$pkgdir" PREFIX=/usr install

	mkdir -p "$pkgdir/usr/lib/systemd/system"
	cp *.service "$pkgdir/usr/lib/systemd/system"
}
