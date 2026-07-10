#
pkgname=picotool
pkgver=2.2.0
pkgrel=1

pkgdesc="Tool for inspecting RP2040 binaries and interacting with RP2040 devices"
arch=(x86_64)
url="https://github.com/raspberrypi/picotool"
license=(BSD-3-Clause)

depends=(gcc-libs libusb)
makedepends=(cmake)

source=(
	"${pkgname}-${pkgver}.tar.gz::${url}/archive/refs/tags/${pkgver}.tar.gz"
	"pico-sdk-${pkgver}.tar.gz::https://github.com/raspberrypi/pico-sdk/archive/refs/tags/${pkgver}.tar.gz"
	"70-picotool.rules"
)
sha256sums=(
	aab3d82fb1e576d97156ddcb962ae7cf290518a5f20d9002ac27e628dc657620
	dbd8db79015aced4ef35cbaa88051b0d451775010d20202e1c7d2bee69c25b35
	e7abda1f88afddc2f49b27d0edce0f2a1daba7c7b90260a5e6fccc456da24b18
)

build() {
	export PICO_SDK_PATH="${srcdir}/pico-sdk-${pkgver}"

	cd "${srcdir}"
	cmake -B build -S "${pkgname}-${pkgver}" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		# EOL
	cmake --build build
}

package() {
	# Install application etc
	DESTDIR="$pkgdir" cmake --install build

	# Install udev rules
	install -Dm644 "${srcdir}/70-picotool.rules" -t "${pkgdir}/usr/lib/udev/rules.d/"

	# Install docs
	install -Dm644 "${srcdir}/${pkgname}-${pkgver}/README.md" -t "${pkgdir}/usr/share/doc/${pkgname}"

	# Install license
	install -Dm644 "${srcdir}/${pkgname}-${pkgver}/LICENSE.TXT" -t "${pkgdir}/usr/share/licenses/${pkgname}"
}
