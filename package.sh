#!/bin/bash

versions=(1.1 1.2)
platforms=(linux)
architectures=(386 amd64 arm)
targets=(rpm deb)

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
	wget https://pkg.cfssl.org/R${version}/${file}
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

	bundle exec fpm -t ${pkg_type} -s dir \
    	  --prefix /usr/bin \
	  --package "../../cfssl_${version}_${arch}.${pkg_type}" \
    	  --name "cfssl" \
  	  --version "${version}" \
	  --architecture ${arch} \
	  --maintainer "Pat Downey <pat.downey+package-cfssl@gmail.com>" \
	  --url "https://github.com/patdowney/package-cfssl" \
	  --deb-user root \
	  --deb-group root \
	  --verbose \
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
        wget https://pkg.cfssl.org/R${ver}/SHA256SUMS

	echo "download version: ${ver}"
	for arch in ${architectures[@]}
	do
		mkdir -p ${arch}
		pushd ${arch}
		download_arch_version ${ver} ${arch}
		for target in ${targets[@]}
		do
			if [ "${arch}" == "386" ]; then
				arch="i386"
			fi
			package_arch_version ${target} ${ver} ${arch}
		done
		popd
	done
	popd
done

