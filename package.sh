#!/bin/bash

if [ -z "${PACKAGE_VERSION}" ]
then
	versions=(1.1 1.2)
else
	versions=${PACKAGE_VERSION}
fi

#architectures=(386 amd64 arm)
if [ -z "${PACKAGE_ARCH}" ];
then
	architectures=(386 amd64 arm)
else
	architectures=${PACKAGE_ARCH}
fi

if [ -z "${PACKAGE_TARGET}" ];
then
	targets=(rpm deb)
else
	targets=${PACKAGE_TARGET}
fi

#targets=(rpm deb)
#targets=${PACKAGE_TARGET:-(deb)}

build_number=${TRAVIS_BUILD_NUMBER:-1}

checksum_file() {
	local file

	file=$1

	openssl dgst -sha256 ${file} | awk '{print $2}'
}

download_file() {
	local version
	local file

	version=$1
	file=$2

	echo "downloading ${version} - ${file}"
	curl -sf -o ${file} https://pkg.cfssl.org/R${version}/${file}
	if [ $? -ne 0 ]; then
		echo "failed to download https://pkg.cfssl.org/R${version}/${file}"
		exit 1
	fi
}

download_arch_version() {
	local version
	local arch

	version=$1
	arch=$2

	for f in $(grep linux-${arch} ../SHA256SUMS | awk '{print $2}')
	do
		base_filename=$(echo ${f} | cut -f1 -d_)

		expected_checksum=$(grep ${f} ../SHA256SUMS | awk '{print $1}')
		if [ ! -f "${base_filename}" ];
		then
			download_file ${version} ${f}
		fi
		if [ -f "${f}" ];
		then
			mv ${f} ${base_filename}
		fi

		downloaded_checksum=$(checksum_file ${base_filename})

		if [ "${expected_checksum}" != "${downloaded_checksum}" ];
		then
			echo "Invalid checksum for \"${f}\" - expected >${expected_checksum}<, got >${downloaded_checksum}<"
			exit 1
		fi

		chmod +x ${base_filename}
	done
}

package_arch_version(){
        local pkg_type
	local version
	local arch

	pkg_type=$1
	version=$2
	arch=$3

	package_arch=${arch}
	if [ "${arch}" == "386" ]; then
		package_arch="i386"
	elif [ "${arch}" == "arm" ]; then
		package_arch="armhf"
	fi

	package_version=${version}-${build_number}
	package_file=cfssl_${package_version}_${package_arch}.${pkg_type}

	rm -f ${package_file}
        cp -rf dist/cfssl ${version}/${arch}
	bundle exec fpm -C ${version}/${arch} -t ${pkg_type} -s dir \
    	  --prefix /usr/bin \
	  --package "${package_file}" \
    	  --name "cfssl" \
          --version "${package_version}" \
	  --architecture ${package_arch} \
	  --description "CloudFlare's PKI toolkit" \
	  --maintainer "Pat Downey <pat.downey+package-cfssl@gmail.com>" \
	  --url "https://github.com/patdowney/package-cfssl" \
	  --rpm-user root \
	  --rpm-group root \
	  --deb-user root \
	  --deb-group root \
          --template-scripts \
          --before-install scripts/before-install.${pkg_type}.sh \
          --after-install scripts//after-install.${pkg_type}.sh \
	  --verbose \
	  ../../dist/cfssl/etc=../.. \
	  ../LICENSE=../share/doc/cfssl/ \
	  .

	if [ $? -ne 0 ]; then
		exit 1
	fi
}

for ver in ${versions[@]}
do
	mkdir -p ${ver}
	pushd ${ver}

        echo "download checksums"
	rm -f SHA256SUMS
	download_file ${ver} SHA256SUMS

	echo "download version: ${ver}"
	for arch in ${architectures[@]}
	do
		mkdir -p ${arch}
		pushd ${arch}
		download_arch_version ${ver} ${arch}
		popd
	done
	popd
done


for ver in ${versions[@]}
do
	# download licence
	curl -o ${ver}/LICENSE https://raw.githubusercontent.com/cloudflare/cfssl/${ver}.0/LICENSE

	for arch in ${architectures[@]}
	do
		for target in ${targets[@]}
		do
			package_arch_version ${target} ${ver} ${arch}
		done
	done
done


