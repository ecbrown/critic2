! Copyright (c) 2007-2022 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
! Ángel Martín Pendás <angel@fluor.quimica.uniovi.es> and Víctor Luaña
! <victor@fluor.quimica.uniovi.es>.
!
! critic2 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or (at
! your option) any later version.
!
! critic2 is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

! Implementation of the critic2 C/C++ library.
submodule (libcritic2) proc
  use iso_c_binding
  implicit none

  ! whether critic2 has been initialized
  logical :: critic2_init = .false.

  !xx! private procedures
  ! subroutine initialize_critic2()

contains

  !> Read a crystal structure from a file. Allocate space for the
  !> crystal structure and return a pointer to it or NULL if there was
  !> an error. Requires destruction of the object after its use.
  module function c2_crystal_from_file(file) bind(c,name="c2_crystal_from_file")
    use crystalmod, only: crystal
    use crystalseedmod, only: crystalseed
    use c_interface_module, only: c_f_string_alloc
    type(c_ptr), value, intent(in) :: file
    type(c_ptr) :: c2_crystal_from_file

    character(len=:), allocatable :: fname
    type(crystalseed) :: seed
    integer :: i
    character(len=:), allocatable :: errmsg
    type(crystal), pointer :: crf

    ! consistency checks
    if (.not.critic2_init) call initialize_critic2()

    ! read seed from file
    c2_crystal_from_file = c_null_ptr
    call c_f_string_alloc(file,fname)
    call seed%read_any_file(fname,-1,errmsg)
    if (len_trim(errmsg) > 0) return

    ! output the crystal
    allocate(crf)
    call crf%struct_new(seed,.false.)
    if (.not.crf%isinit) return
    c2_crystal_from_file = c_loc(crf)

  end function c2_crystal_from_file

  !> Create a crystal structure from the lattice parameters (lattice,
  !> in bohr), number of atoms (natom), atomic positions (position,
  !> fractional coords), and atomic numbers (zat). Allocate space for
  !> the crystal structure and return a pointer to it or NULL if there
  !> was an error. Requires destruction of the object after its use.
  module function c2_crystal_from_lattice(natom,lattice,position,zat) bind(c,name="c2_crystal_from_lattice")
    use crystalmod, only: crystal
    use crystalseedmod, only: crystalseed
    use tools_io, only: nameguess
    use param, only: maxzat0
    integer(c_int), intent(in), value :: natom
    real(c_double), intent(in) :: lattice(3,3)
    real(c_double), intent(in) :: position(3,natom)
    integer(c_int), intent(in) :: zat(natom)
    type(c_ptr) :: c2_crystal_from_lattice

    integer :: isused(maxzat0)
    type(crystalseed) :: seed
    integer :: i
    type(crystal), pointer :: crf

    ! consistency checks
    if (.not.critic2_init) call initialize_critic2()

    ! build seed from lattice info
    c2_crystal_from_lattice = c_null_ptr
    call seed%end()
    seed%m_x2c = lattice
    seed%useabr = 2

    ! atomic positions and types
    isused = 0
    seed%nat = natom
    seed%nspc = 0
    allocate(seed%x(3,seed%nat),seed%is(seed%nat))
    seed%x = position
    do i = 1, natom
       if (zat(i) <= 0 .or. zat(i) > maxzat0) return
       if (isused(zat(i)) == 0) then
          seed%nspc = seed%nspc + 1
          isused(zat(i)) = seed%nspc
       end if
       seed%is(i) = isused(zat(i))
    end do

    ! atomic species
    allocate(seed%spc(seed%nspc))
    do i = 1, maxzat0
       if(isused(i) > 0) then
          seed%spc(isused(i))%z = i
          seed%spc(isused(i))%name = nameguess(i)
       end if
    end do

    ! rest of info
    seed%isused = .true.
    seed%ismolecule = .false.

    ! output the crystal
    allocate(crf)
    call crf%struct_new(seed,.false.)
    if (.not.crf%isinit) return
    c2_crystal_from_lattice = c_loc(crf)

  end function c2_crystal_from_lattice

  !> Create a crystal structure from the cell lengths (cel, in bohr),
  !> cell angles (ang, degrees), number of atoms (natom), atomic
  !> positions (position, fractional coords), and atomic numbers
  !> (zat). Allocate space for the crystal structure and return a
  !> pointer to it or NULL if there was an error. Requires destruction
  !> of the object after its use.
  module function c2_crystal_from_cellpar(natom,cel,ang,position,zat) bind(c,name="c2_crystal_from_cellpar")
    use tools_math, only: m_x2c_from_cellpar
    integer(c_int), intent(in), value :: natom
    real(c_double), intent(in) :: cel(3)
    real(c_double), intent(in) :: ang(3)
    real(c_double), intent(in) :: position(3,natom)
    integer(c_int), intent(in) :: zat(natom)
    type(c_ptr) :: c2_crystal_from_cellpar

    real(c_double) :: lattice(3,3)

    lattice = m_x2c_from_cellpar(cel,ang)
    c2_crystal_from_cellpar = c2_crystal_from_lattice(natom,lattice,position,zat)

  end function c2_crystal_from_cellpar

  !> Write the report about the input crystal structure to standard output.
  module subroutine c2_describe_crystal(cr) bind(c,name="c2_describe_crystal")
    use crystalmod, only: crystal
    type(c_ptr), value, intent(in) :: cr

    type(crystal), pointer :: crf

    ! consistency checks
    if (.not.critic2_init) call initialize_critic2()
    if (.not.c_associated(cr)) return
    call c_f_pointer(cr,crf)
    if (.not.associated(crf)) return

    ! write the report
    call crf%report(.true.,.false.)

  end subroutine c2_describe_crystal

  !> Destroy the input crystal structure object and free the memory.
  module subroutine c2_destroy_crystal(cr) bind(c,name="c2_destroy_crystal")
    use crystalmod, only: crystal
    type(c_ptr), value, intent(in) :: cr

    type(crystal), pointer :: crf

    ! consistency checks
    if (.not.critic2_init) call initialize_critic2()
    if (.not.c_associated(cr)) return
    call c_f_pointer(cr,crf)
    if (.not.associated(crf)) return

    ! destroy the crystal object and free memory
    call crf%end()
    deallocate(crf)

  end subroutine c2_destroy_crystal

  !xx! private procedures

  !> Initialize critic2 when used as a library.
  subroutine initialize_critic2()
    use spglib, only: spg_build_hall_mapping
    use systemmod, only: systemmod_init
    use global, only: global_init, fileroot, initial_banner, config_write
    use tools_io, only: start_clock, stdargs, history_init
    use param, only: param_init
    use config, only: getstring, istring_datadir

    character(len=:), allocatable :: optv, ghome

    ! initialize
    call start_clock()
    call param_init()

    call stdargs(optv,ghome,fileroot)
    call history_init()

    call global_init(ghome,getstring(istring_datadir))
    call systemmod_init(1)
    call spg_build_hall_mapping() ! for spglib
    critic2_init = .true.

  end subroutine initialize_critic2

end submodule proc
