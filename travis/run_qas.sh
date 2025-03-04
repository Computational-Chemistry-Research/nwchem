#!/bin/bash 
# Exit on error
set -e
# source env. variables
if [[ -z "$TRAVIS_BUILD_DIR" ]] ; then
    TRAVIS_BUILD_DIR=$(pwd)
fi
source $TRAVIS_BUILD_DIR/travis/nwchem.bashrc
# check if nwchem binary has been cached
echo NWCHEM_EXECUTABLE is "$NWCHEM_EXECUTABLE"
if [[ -f "$NWCHEM_EXECUTABLE" ]] ; then
    EXTRA_BUILD=0
else
    echo 'Cached NWChem binary not found, recompiling'
    $TRAVIS_BUILD_DIR/travis/config_nwchem.sh 
    $TRAVIS_BUILD_DIR/travis/compile_nwchem.sh
    EXTRA_BUILD=1
fi
if [[ "$BUILD_MPICH" == 1 ]] ; then
    export PATH=$TRAVIS_BUILD_DIR/src/libext/bin:$PATH
    export MPIRUN_PATH=$TRAVIS_BUILD_DIR/src/libext/bin/mpirun
fi

os=`uname`
arch=`uname -m`
export NWCHEM_BASIS_LIBRARY=$TRAVIS_BUILD_DIR/.cachedir/files/libraries/
export NWCHEM_NWPW_LIBRARY=$TRAVIS_BUILD_DIR/.cachedir/files/libraryps/
nprocs=2
if [[ ! -z "$USE_OPENMP" ]]; then
    nprocs=1
    export OMP_NUM_THREADS="$USE_OPENMP"
    export OMP_STACKSIZE=32M
fi
if [[ "$arch" == "aarch64" ]] ; then
    nprocs=1
fi    
env|egrep MP
 do_largeqas=1

 if [[ "$EXTRA_BUILD" == "1" ]] || [[ ! -z "$USE_SIMINT" ]] || [[ "$arch" == "aarch64" ]] || [[ "$arch" == "ppc64le" ]]; then
     do_largeqas=0
 fi

 if [[ "$os" == "Linux" && "$MPI_IMPL" == "mpich" ]]; then
    export MPIRUN_PATH=/usr/bin/mpirun.mpich
 fi
 if [[ "$os" == "Darwin" && "NWCHEM_MODULES" == "tce" ]]; then
    do_largeqas=0
 fi
 case "$ARMCI_NETWORK" in
    MPI-PR)
	nprocs=$(( nprocs + 1 ))
	case "$MPI_IMPL" in
	    openmpi)
		export MPIRUN_NPOPT="-mca mpi_yield_when_idle 0 --oversubscribe -np "
		;;
	esac
        case "$os" in
            Darwin)
                do_largeqas=0
            ;;
        esac
	;;
    SOCKETS)
        do_largeqas=0
        ;;
    MPI-MT)
        do_largeqas=0
        ;;
    MPI-PT)
        do_largeqas=0
        ;;
    MPI3)
        case "$os" in
            Darwin)
                do_largeqas=0
		;;
	esac
	;;
 esac
if [[ "$MPI_IMPL" == "openmpi" ]]; then
export MPIRUN_NPOPT=" --allow-run-as-root -mca mpi_yield_when_idle 0 --oversubscribe -np "
fi
 echo === ls binaries cache ===
 ls -lrt $TRAVIS_BUILD_DIR/.cachedir/binaries/$NWCHEM_TARGET/ || true
 echo =========================
 if [[ -z "$TRAVIS_HOME" ]]; then
     echo 'no using sleep loop'
 else
     export USE_SLEEPLOOP=1
 fi
 if [[ "$NWCHEM_MODULES" == "tce" ]]; then
   cd $TRAVIS_BUILD_DIR/QA &&  ./runtests.mpi.unix procs $nprocs tce_n2 tce_ccsd_t_h2o tce_h2o_eomcc
   cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs tce_cc2_c2
   cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs ducc_be
 if  [[ "$do_largeqas" == 1 ]]; then
	cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs tce_ipccsd_f2 tce_eaccsd_ozone
    fi
 else
# check if dft is among modules
     if [[ ! $(grep -i dft $TRAVIS_BUILD_DIR/src/stubs.F| awk '/dft_input/') ]]; then
	 cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs dft_he2+
	 if [[ ! $(grep -i prop $TRAVIS_BUILD_DIR/src/stubs.F| awk '/prop_input/') ]]; then
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs prop_mep_gcube
	 fi
	 if [[ ! $(grep -i cosmo $TRAVIS_BUILD_DIR/src/stubs.F| awk '/cosmo_input/') ]]; then
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs cosmo_h2o_dft
	 fi
     else
	 echo ' dft_input stubbed'
     fi
     if [[ "$USE_SIMINT" != "1" ]] ; then
# check if pspw is among modules
	 if [[ ! $(grep -i pspw $TRAVIS_BUILD_DIR/src/stubs.F| awk '/pspw_input/') ]]; then
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs pspw
	 fi
     fi
# check if python is among modules
     if [[ ! $(grep -i python $TRAVIS_BUILD_DIR/src/stubs.F| awk '/python_input/') ]]; then
     	 cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs pyqa3
     fi
     if  [[ "$do_largeqas" == 1 ]]; then
	 if [[ ! $(grep -i dft $TRAVIS_BUILD_DIR/src/stubs.F| awk '/dft_input/') ]]; then
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs dft_siosi3 h2o_opt
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs tddft_h2o
	     if [[ ! $(grep -i prop $TRAVIS_BUILD_DIR/src/stubs.F| awk '/prop_input/') ]]; then
		 cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs h2o2-response
	     fi
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs dft_scan
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs dft_ncap
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs dft_ch3_h2o_revm06
	     cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs dft_smear
	 fi
       if [[ ! $(grep -i mp2_input $TRAVIS_BUILD_DIR/src/stubs.F| awk '/mp2_input/') ]]; then
	   if [[ ! $(grep -i ccsd_input $TRAVIS_BUILD_DIR/src/stubs.F| awk '/ccsd_input/') ]]; then
	       cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs n2_ccsd h2mp2 auh2o aump2
	   fi
       fi
       if [[ ! $(grep -i pspw $TRAVIS_BUILD_DIR/src/stubs.F| awk '/pspw_input/') ]]; then
#skip pspw_md when openmp is on
	   if [[ -z "$USE_OPENMP" ]]; then
	       cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs pspw_md
	   fi
       fi
       if [[ ! $(grep -i dft_input $TRAVIS_BUILD_DIR/src/stubs.F| awk '/dft_input/') ]]; then
	   if [[ ! $(grep -i prop_input $TRAVIS_BUILD_DIR/src/stubs.F| awk '/prop_input/') ]]; then
	       cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs ch3radical_unrot
	   fi
	   cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs rt_tddft_dimer_charge
	   # check if qmd is among modules
	   if [[ ! $(grep -i qmd $TRAVIS_BUILD_DIR/src/stubs.F| awk '/qmd/') ]]; then
               cd $TRAVIS_BUILD_DIR/QA && ./runtests.mpi.unix procs $nprocs qmd_dft_h2o_svr
	   fi
       fi
     fi
 fi
