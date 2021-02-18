! Copyright (c) 2007-2018 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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

submodule (struct_drivers) proc
  implicit none

contains

  !xx! top-level routines
  !> Parse the input of the crystal keyword (line) and return an
  !> initialized crystal c. mol0=1, interpret the structure as a
  !> molecule; mol0=0, a crystal, mol0=-1, guess. If allownofile
  !> allow the program to read the following input lines to parse
  !> the crystal/molecule environment.
  module subroutine struct_crystal_input(line,mol0,allownofile,verbose,s0,cr0,seed0)
    use systemmod, only: system
    use crystalmod, only: crystal
    use param, only: isformat_cif, isformat_shelx, isformat_f21,&
       isformat_cube, isformat_bincube, isformat_struct, isformat_abinit,&
       isformat_elk,&
       isformat_qein, isformat_qeout, isformat_crystal, isformat_xyz,&
       isformat_wfn, isformat_wfx, isformat_fchk, isformat_molden,&
       isformat_gaussian, isformat_siesta, isformat_xsf, isformat_gen,&
       isformat_vasp, isformat_pwc, isformat_axsf, isformat_dat,&
       isformat_pgout, isformat_orca, isformat_dmain
    use crystalseedmod, only: crystalseed, struct_detect_format
    use global, only: doguess, iunit, dunit0, rborder_def, eval_next
    use tools_io, only: getword, equal, ferror, faterr, zatguess, lgetword,&
       string, uin, isinteger, isreal, lower
    use types, only: realloc
    character*(*), intent(in) :: line
    integer, intent(in) :: mol0
    logical, intent(in) :: allownofile
    logical, intent(in) :: verbose
    type(system), intent(inout), optional :: s0
    type(crystal), intent(inout), optional :: cr0
    type(crystalseed), intent(inout), optional :: seed0

    integer :: lp, lp2, istruct
    character(len=:), allocatable :: word, word2, subline
    integer :: nn, isformat
    real*8 :: rborder, raux, xnudge
    logical :: docube, ok, ismol, mol, hastypes
    type(crystalseed) :: seed
    character(len=:), allocatable :: errmsg

    ! read and parse
    lp=1
    lp2=1
    word = getword(line,lp)
    subline = line(lp:)
    word2 = getword(line,lp)
    if (len_trim(word2) == 0) word2 = " "

    ! detect the format for this file
    call struct_detect_format(word,isformat,ismol)

    ! is this a crystal or a molecule?
    if (mol0 == 1) then
       mol = .true.
    elseif (mol0 == 0) then
       mol = .false.
    elseif (mol0 == -1) then
       mol = ismol
    else
       call ferror("struct_crystal_input","unknown mol0",faterr)
    end if
    if (ismol) then
       docube = .false.
       rborder = rborder_def
       do while(.true.)
          if (equal(word2,'cubic').or.equal(word2,'cube')) then
             docube = .true.
          elseif (eval_next(raux,word2,lp2)) then
             rborder = raux / dunit0(iunit)
          elseif (len_trim(word2) > 1) then
             call ferror('struct_crystal_input','Unknown extra keyword',faterr,line,syntax=.true.)
             return
          else
             exit
          end if
          lp2 = 1
          word2 = lgetword(line,lp)
       end do
    end if

    ! build the seed
    errmsg = ""
    if (isformat == isformat_cif) then
       call seed%read_cif(word,word2,mol,errmsg)

    elseif (isformat == isformat_shelx) then
       call seed%read_shelx(word,mol,errmsg)

    elseif (isformat == isformat_f21) then
       call seed%read_f21(word,mol,errmsg)

    elseif (isformat == isformat_cube) then
       call seed%read_cube(word,mol,errmsg)

    elseif (isformat == isformat_bincube) then
       call seed%read_bincube(word,mol,errmsg)

    elseif (isformat == isformat_struct) then
       call seed%read_wien(word,mol,errmsg)

    elseif (isformat == isformat_vasp) then
       seed%nspc = 0
       if (index(word2,'POTCAR') > 0) then
          call seed%read_potcar(word2,errmsg)
       else
          allocate(seed%spc(2))
          do while(.true.)
             nn = zatguess(word2)
             if (nn >= 0) then
                seed%nspc = seed%nspc + 1
                if (seed%nspc > size(seed%spc,1)) &
                   call realloc(seed%spc,2*seed%nspc)
                seed%spc(seed%nspc)%name = string(word2)
                seed%spc(seed%nspc)%z = zatguess(word2)
             else
                if (len_trim(word2) > 0) then
                   call ferror('struct_crystal_input','Unknown atom type in CRYSTAL',faterr,line,syntax=.true.)
                   return
                end if
                exit
             end if
             word2 = getword(line,lp)
          end do
       end if
       if (len_trim(errmsg) == 0) then
          call seed%read_vasp(word,mol,hastypes,errmsg)
          if (len_trim(errmsg) == 0 .and..not.hastypes) &
             errmsg = "Atom types not found (use POTCAR or give atom types after structure file)"
       end if

    elseif (isformat == isformat_abinit) then
       call seed%read_abinit(word,mol,errmsg)

    elseif (isformat == isformat_elk) then
       call seed%read_elk(word,mol,errmsg)

    elseif (isformat == isformat_qeout) then
       lp2 = 1
       ok = isinteger(istruct,word2,lp2)
       if (.not.ok) istruct = 0
       call seed%read_qeout(word,mol,istruct,errmsg)

    elseif (isformat == isformat_crystal) then
       call seed%read_crystalout(word,mol,errmsg)

    elseif (isformat == isformat_qein) then
       call seed%read_qein(word,mol,errmsg)

    elseif (isformat == isformat_xyz.or.isformat == isformat_wfn.or.&
       isformat == isformat_wfx.or.isformat == isformat_fchk.or.&
       isformat == isformat_molden.or.isformat == isformat_gaussian.or.&
       isformat == isformat_dat.or.isformat == isformat_pgout.or.&
       isformat == isformat_orca) then
       call seed%read_mol(word,isformat,rborder,docube,errmsg)

    elseif (isformat == isformat_siesta) then
       call seed%read_siesta(word,mol,errmsg)

    elseif (isformat == isformat_xsf) then
       call seed%read_xsf(word,rborder,docube,errmsg)
       if (mol0 /= -1) &
          seed%ismolecule = mol

    elseif (isformat == isformat_gen) then
       call seed%read_dftbp(word,rborder,docube,errmsg)
       if (mol0 /= -1) &
          seed%ismolecule = mol

    elseif (isformat == isformat_pwc) then
       call seed%read_pwc(word,mol,errmsg)
       if (mol0 /= -1) &
          seed%ismolecule = mol

    elseif (isformat == isformat_axsf) then
       istruct = 1
       xnudge = 0d0

       lp2 = 1
       ok = isinteger(nn,word2,lp2)
       if (ok) then
          istruct = nn
          word2 = getword(line,lp)
          lp2 = 1
          ok = isreal(raux,word2,lp2)
          if (ok) xnudge = raux
       end if

       call seed%read_axsf(word,istruct,xnudge,rborder,docube,errmsg)
       if (mol0 /= -1) &
          seed%ismolecule = mol

    elseif (isformat == isformat_dmain) then
       call seed%read_dmain(word,mol,errmsg)

    else if (equal(lower(word),'library')) then
       call seed%read_library(subline,mol,ok)
       if (.not.ok) return

    else if (len_trim(word) < 1) then
       if (.not.allownofile) then
          call ferror('struct_crystal_input','Attempted to parse CRYSTAL/MOLECULE but allownofile=.true.',faterr,syntax=.true.)
          return
       end if

       if (.not.mol) then
          call seed%parse_crystal_env(uin,ok)
          if (.not.ok) return
       else
          call seed%parse_molecule_env(uin,ok)
          if (.not.ok) return
       endif
    else
       call ferror('struct_crystal_input','unrecognized file format',faterr,line,syntax=.true.)
       return
    end if
    if (len_trim(errmsg) > 0) then
       call ferror('struct_crystal_input',errmsg,faterr,line,syntax=.true.)
       return
    end if

    ! handle the doguess option
    if (.not.seed%ismolecule) then
       if (doguess == 0) then
          seed%findsym = 0
       elseif (doguess == 1 .and. seed%havesym == 0) then
          seed%findsym = 1
       end if
    end if

    if (present(s0)) then
       call s0%new_from_seed(seed)
       if (verbose) &
          call s0%report(.true.,.true.,.true.,.true.,.true.,.true.,.false.)
    end if
    if (present(cr0)) then
       call cr0%struct_new(seed,.true.)
       if (verbose) &
          call cr0%report(.true.,.true.)
    end if
    if (present(seed0)) then
       seed0 = seed
    end if

  end subroutine struct_crystal_input

  !> Clear the symmetry in the system.
  module subroutine struct_sym(s,line,verbose)
    use iso_c_binding, only: c_double
    use crystalseedmod, only: crystalseed
    use spglib, only: SpglibDataset, spg_standardize_cell
    use global, only: symprec
    use tools_math, only: matinv
    use tools_io, only: uout, lgetword, equal, isinteger, ferror, faterr, string
    type(system), intent(inout) :: s
    character*(*), intent(in) :: line
    logical, intent(in) :: verbose

    character(len=:), allocatable :: word, errmsg
    integer :: lp, i
    real*8 :: osp
    type(SpglibDataset) :: spg
    real*8 :: x0(3,3)
    logical :: isempty

    real*8, parameter :: spmin = 1d-20
    real*8, parameter :: factor = 10d0

    ! header
    write (uout,'("* SYM: manipulation of the crystal symmetry.")')
    write (uout,*)

    ! no molecules here
    if (s%c%ismolecule) then
       call ferror('struct_sym','Symmetry not available in a MOLECULE',faterr,line,syntax=.true.)
       return
    end if

    ! parse the input
    isempty = .false.
    lp = 1
    word = lgetword(line,lp)
    if (equal(word,'clear')) then
       write (uout,'("+ CLEAR the symmetry for this crystal structure.")')
       call s%clearsym()

    elseif (equal(word,'recalc')) then
       write (uout,'("+ RECALCULATE the symmetry operations.")')
       call s%c%calcsym(.false.,errmsg)
       if (len_trim(errmsg) > 0) &
          call ferror("struct_sym","spglib: "//errmsg,faterr)

    elseif (equal(word,'analysis')) then
       write (uout,'("+ ANALYSIS of the crystal symmetry.")')
       write (uout,*)
       osp = symprec

       write (uout,'("# Sym.Prec. Space group")')
       symprec = spmin / factor
       do i = 1, 21
          symprec = symprec * factor
          call s%c%spglib_wrap(spg,.false.,errmsg)
          if (len_trim(errmsg) > 0) exit
          write (uout,'(1p,2X,A,A,X,"(",A,")")') string(symprec,'e',10,2), string(spg%international_symbol), &
             string(spg%spacegroup_number)
       end do
       write (uout,*)
       symprec = osp
       return ! do not clear the fields or re-write the structure

    elseif (equal(word,'refine')) then
       x0 = s%c%cell_standard(.false.,.false.,.true.)

    elseif (equal(word,'wholemols')) then
       if (.not.s%c%ismol3d) then
          call ferror('struct_sym','Cannot apply WHOLEMOLS to a non-molecular crystal',faterr,line,syntax=.true.)
          return
       end if
       call s%c%wholemols()

    else
       isempty = .true.
       call s%c%struct_report_symmetry()
    end if

    ! clear the fields and report the new structure
    if (.not.isempty) then
       call s%reset_fields()
       if (verbose) &
          call s%report(.true.,.true.,.true.,.true.,.true.,.true.,.false.)
    end if

  end subroutine struct_sym

  !> Change the charges and pseudopotential charges in the system.
  module subroutine struct_charges(s,line,oksyn)
    use systemmod, only: system
    use grid1mod, only: grid1_register_core
    use global, only: eval_next
    use tools_io, only: lgetword, equal, ferror, faterr, getword, zatguess
    use param, only: maxzat0
    type(system), intent(inout) :: s
    character*(*), intent(in) :: line
    logical, intent(out) :: oksyn

    character(len=:), allocatable :: word
    integer :: lp, nn, i, j, zpsp0(maxzat0)
    logical :: ok, do1
    real*8 :: xx

    oksyn = .false.
    lp = 1
    word = lgetword(line,lp)
    zpsp0 = -2
    if (equal(word,'q') .or. equal(word,'zpsp') .or. equal(word,'qat')) then
       do1 = equal(word,'zpsp')
       do while (.true.)
          word = getword(line,lp)
          if (len_trim(word) < 1) exit
          nn = zatguess(word)
          if (nn == -1) then
             call ferror('struct_charges','Unknown atomic symbol in Q/QAT/ZPSP',faterr,line,syntax=.true.)
             return
          end if
          ok = eval_next(xx,line,lp)
          if (.not.ok) then
             call ferror('struct_charges','Incorrect Q/QAT/ZPSP syntax',faterr,line,syntax=.true.)
             return
          end if
          if (.not.do1) then
             do i = 1, s%c%nspc
                if (s%c%spc(i)%z == nn) &
                   s%c%spc(i)%qat = xx
             end do
          else
             zpsp0(nn) = nint(xx)
             if (nn > 0 .and. zpsp0(nn) > 0) &
                call grid1_register_core(nn,zpsp0(nn))
          end if
       end do
    elseif (equal(word,'nocore')) then
       zpsp0 = -1
       word = getword(line,lp)
       if (len_trim(word) > 0) then
          call ferror('critic','Unknown extra keyword',faterr,line,syntax=.true.)
          return
       end if
    endif
    oksyn = .true.

    ! fill the crystal zpsp
    do j = 1, maxzat0
       if (zpsp0(j) /= -2) &
          s%c%zpsp(j) = zpsp0(j)
    end do

    ! fill the current fields zpsp
    do i = 1, s%nf
       if (s%f(i)%isinit) then
          do j = 1, maxzat0
             if (zpsp0(j) /= -2) &
                s%f(i)%zpsp(j) = zpsp0(j)
          end do
       end if
    end do

    ! report the charges and zpsp
    call s%c%report(.false.,.true.)
    call s%report(.false.,.false.,.false.,.false.,.false.,.true.,.false.)

  end subroutine struct_charges

  ! Write the crystal structure to a file
  module subroutine struct_write(s,line)
    use systemmod, only: system
    use global, only: eval_next, dunit0, iunit
    use tools_io, only: getword, equal, lower, lgetword, ferror, faterr, uout, &
       string, warning
    type(system), intent(inout) :: s
    character*(*), intent(in) :: line

    character(len=:), allocatable :: word, wext, file, wroot
    integer :: lp, ix(3), lp2, iaux, nmer
    logical :: doborder, molmotif, dosym, docell, domolcell, ok
    logical :: onemotif, environ, lnmer
    real*8 :: rsph, xsph(3), rcub, xcub(3), renv, rk

    lp = 1
    file = getword(line,lp)
    wext = lower(file(index(file,'.',.true.)+1:))
    wroot = file(:index(file,'.',.true.)-1)

    if (equal(wext,'xyz').or.equal(wext,'gjf').or.equal(wext,'cml').or.&
        equal(wext,'obj').or.equal(wext,'ply').or.equal(wext,'off')) then
       ! xyz, gjf, cml, obj, ply, off
       doborder = .false.
       lnmer = .false.
       onemotif = .false.
       molmotif = .false.
       environ = .false.
       docell = .false.
       domolcell = .false.
       nmer = 1
       ix = 1
       rsph = -1d0
       xsph = 0d0
       rcub = -1d0
       xcub = 0d0
       renv = 0d0
       do while(.true.)
          word = lgetword(line,lp)
          lp2 = 1
          if (equal(word,'border')) then
             doborder = .true.
          elseif (equal(word,'onemotif')) then
             onemotif = .true.
          elseif (equal(word,'molmotif')) then
             molmotif = .true.
          elseif (equal(word,'environ')) then
             environ = .true.
             ok = eval_next(renv,line,lp)
             if (.not.ok) &
                call ferror('struct_write','incorrect ENVIRON',faterr,line,syntax=.true.)
             renv = renv / dunit0(iunit)
          elseif (equal(word,'nmer')) then
             lnmer = .true.
             ok = eval_next(nmer,line,lp)
             if (.not.ok) &
                call ferror('struct_write','incorrect NMER',faterr,line,syntax=.true.)
          elseif (equal(word,'cell')) then
             docell = .true.
          elseif (equal(word,'molcell')) then
             domolcell = .true.
          elseif (equal(word,'sphere')) then
             ok = eval_next(rsph,line,lp)
             ok = ok .and. eval_next(xsph(1),line,lp)
             if (ok) then
                ok = ok .and. eval_next(xsph(2),line,lp)
                ok = ok .and. eval_next(xsph(3),line,lp)
                if (.not.ok) then
                   call ferror('struct_write','incorrect WRITE SPHERE syntax',faterr,line,syntax=.true.)
                   return
                end if
             else
                xsph = 0d0
             end if
             ! convert units and coordinates
             rsph = rsph / dunit0(iunit)
             if (s%c%ismolecule) then
                xsph = xsph / dunit0(iunit) - s%c%molx0
                xsph = s%c%c2x(xsph)
             endif
          elseif (equal(word,'cube')) then
             ok = eval_next(rcub,line,lp)
             ok = ok .and. eval_next(xcub(1),line,lp)
             if (ok) then
                ok = ok .and. eval_next(xcub(2),line,lp)
                ok = ok .and. eval_next(xcub(3),line,lp)
                if (.not.ok) then
                   call ferror('struct_write','incorrect WRITE CUBE syntax',faterr,line,syntax=.true.)
                   return
                end if
             else
                xcub = 0d0
             end if
             ! convert units and coordinates
             rcub = rcub / dunit0(iunit)
             if (s%c%ismolecule) then
                xcub = xcub / dunit0(iunit) - s%c%molx0
                xcub = s%c%c2x(xcub)
             endif
          elseif (eval_next(iaux,word,lp2)) then
             ix(1) = iaux
             ok = eval_next(ix(2),line,lp)
             ok = ok .and. eval_next(ix(3),line,lp)
             if (.not.ok) then
                call ferror('struct_write','incorrect WRITE syntax',faterr,line,syntax=.true.)
                return
             end if
          elseif (len_trim(word) > 1) then
             call ferror('struct_write','Unknown extra keyword',faterr,line,syntax=.true.)
             return
          else
             exit
          end if
       end do

       if (.not.lnmer) then
          write (uout,'("* WRITE ",A," file: ",A)') trim(wext), string(file)
       else
          write (uout,'("* WRITE ",A," files: ",A,"_*.",A)') trim(wext), &
             string(wroot), trim(wext)
       end if

       if (equal(wext,'xyz').or.equal(wext,'gjf').or.equal(wext,'cml')) then
          call s%c%write_mol(file,wext,ix,doborder,onemotif,molmotif,&
             environ,renv,lnmer,nmer,rsph,xsph,rcub,xcub)
       else
          call s%c%write_3dmodel(file,wext,ix,doborder,onemotif,molmotif,&
             docell,domolcell,rsph,xsph,rcub,xcub)
       end if
    elseif (equal(wext,'gau')) then
       ! gaussian periodic boundary conditions
       write (uout,'("* WRITE Gaussian file: ",A)') string(file)
       call s%c%write_gaussian(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'in')) then
       ! espresso
       ok = eval_next(rk,line,lp)
       write (uout,'("* WRITE espresso file: ",A)') string(file)
       if (ok) then
          call s%c%write_espresso(file,rk)
       else
          call s%c%write_espresso(file)
       end if

    elseif (equal(wext,'poscar') .or. equal(wext,'contcar')) then
       ! vasp
       write (uout,'("* WRITE VASP file: ",A)') string(file)
       call s%c%write_vasp(file,.true.)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'abin')) then
       ! abinit
       write (uout,'("* WRITE abinit file: ",A)') string(file)
       call s%c%write_abinit(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'elk')) then
       ! elk
       write (uout,'("* WRITE elk file: ",A)') string(file)
       call s%c%write_elk(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'tess')) then
       ! tessel
       write (uout,'("* WRITE tess file: ",A)') string(file)
       call s%c%write_tessel(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'incritic').or.equal(wext,'cri')) then
       ! critic2
       write (uout,'("* WRITE critic2 input file: ",A)') string(file)
       call s%c%write_critic(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'cif') .or. equal(wext,'d12') .or. equal(wext,'res')) then
       ! cif and d12
       dosym = .true.
       do while(.true.)
          word = lgetword(line,lp)
          if (equal(word,'nosym').or.equal(word,'nosymm')) then
             dosym = .false.
          elseif (len_trim(word) > 1) then
             call ferror('struct_write','Unknown extra keyword',faterr,line,syntax=.true.)
             return
          else
             exit
          end if
       end do

       if (equal(wext,'cif')) then
          write (uout,'("* WRITE cif file: ",A)') string(file)
          call s%c%write_cif(file,dosym)
       elseif (equal(wext,'d12')) then

          write (uout,'("* WRITE crystal file: ",A)') string(file)
          if (.not.s%c%ismolecule.and.dosym) &
             write (uout,'(/"+ WRITE fort.34 file: ",A)') file(:index(file,'.',.true.)-1) // ".fort.34"

          if (dosym .and. (&
             (s%c%spg%spacegroup_number == 146 .and. s%c%spg%n_operations == 3) .or.&
             (s%c%spg%spacegroup_number == 148 .and. s%c%spg%n_operations == 6) .or.&
             (s%c%spg%spacegroup_number == 155 .and. s%c%spg%n_operations == 6) .or.&
             (s%c%spg%spacegroup_number == 160 .and. s%c%spg%n_operations == 6) .or.&
             (s%c%spg%spacegroup_number == 161 .and. s%c%spg%n_operations == 6) .or.&
             (s%c%spg%spacegroup_number == 166 .and. s%c%spg%n_operations == 12) .or.&
             (s%c%spg%spacegroup_number == 167 .and. s%c%spg%n_operations == 12))) then
             call ferror('struct_write',&
                'deactivating symmetry in d12 writer due to bug in crystal17 (EXTERNAL keyword, spg=161, rhombohedral)',&
                warning)
             dosym = .false.
          end if
          call s%c%write_d12(file,dosym)
       elseif (equal(wext,'res')) then
          write (uout,'("* WRITE res file: ",A)') string(file)
          call s%c%write_res(file,dosym)
       end if
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'m')) then
       ! escher
       write (uout,'("* WRITE escher file: ",A)') string(file)
       call s%c%write_escher(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'db')) then
       ! db
       write (uout,'("* WRITE db file: ",A)') string(file)
       call s%c%write_db(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'gin')) then
       ! gulp
       write (uout,'("* WRITE gulp file: ",A)') string(file)
       call s%c%write_gulp(file)
    elseif (equal(wext,'lammps')) then
       write (uout,'("* WRITE lammps file: ",A)') string(file)
       call s%c%write_lammps(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'fdf')) then
       write (uout,'("* WRITE fdf file: ",A)') string(file)
       call s%c%write_siesta_fdf(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'struct_in')) then
       write (uout,'("* WRITE STRUCT_IN file: ",A)') string(file)
       call s%c%write_siesta_in(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'hsd')) then
       write (uout,'("* WRITE hsd file: ",A)') string(file)
       call s%c%write_dftbp_hsd(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'gen')) then
       write (uout,'("* WRITE gen file: ",A)') string(file)
       call s%c%write_dftbp_gen(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    elseif (equal(wext,'pyscf')) then
       ! pyscf (python script)
       write (uout,'("* WRITE pyscf file: ",A)') string(file)
       call s%c%write_pyscf(file)
       ok = check_no_extra_word()
       if (.not.ok) return
    else
       call ferror('struct_write','unrecognized file format',faterr,line,syntax=.true.)
       return
    end if
    write (uout,*)

  contains
    function check_no_extra_word()
      character(len=:), allocatable :: aux2
      logical :: check_no_extra_word

      check_no_extra_word = .true.
      do while (.true.)
         aux2 = getword(line,lp)
         if (equal(aux2,'primitive')) cycle
         if (len_trim(aux2) > 0) then
            call ferror('struct_write','Unknown extra keyword',faterr,line,syntax=.true.)
            check_no_extra_word = .false.
         end if
         exit
      end do

    end function check_no_extra_word
  end subroutine struct_write

  !> Relabel atoms based on user's input
  module subroutine struct_atomlabel(s,line)
    use systemmod, only: system
    use global, only: iunitname0, dunit0, iunit
    use tools_io, only: tab, string, nameguess, lower, ioj_center, uout, equal
    use types, only: species, realloc
    type(system), intent(inout) :: s
    character*(*), intent(in) :: line

    character(len=:), allocatable :: templ, aux, aux2

    integer :: i, j, inum, idx, iz
    integer :: nspc
    integer, allocatable :: is(:)
    type(species), allocatable :: spc(:)
    logical :: found

    nspc = 0
    allocate(spc(1))
    allocate(is(s%c%nneq))

    ! clean up the input label and build the template
    templ = trim(adjustl(line))
    aux = ""
    do i = 1, len(templ)
       if (templ(i:i) == "'" .or. templ(i:i) == '"' .or. templ(i:i) == tab) cycle
       aux2 = trim(aux) // templ(i:i)
       aux = aux2
    end do
    templ = aux

    do i = 1, s%c%nneq
       iz = s%c%spc(s%c%at(i)%is)%z
       aux = trim(templ)
       do while(.true.)
          if (index(aux,"%aid") > 0) then
             ! the absolute index for this atom
             idx = index(aux,"%aid")
             aux2 = aux(1:idx-1) // string(i) // aux(idx+4:)
             aux = trim(aux2)
          elseif (index(aux,"%id") > 0) then
             ! the index by counting atoms only of this type
             inum = 0
             do j = 1, i
                if (s%c%spc(s%c%at(j)%is)%z == iz) inum = inum + 1
             end do
             idx = index(aux,"%id")
             aux2 = aux(1:idx-1) // string(inum) // aux(idx+3:)
             aux = trim(aux2)
          elseif (index(aux,"%S") > 0) then
             ! the atomic symbol
             idx = index(aux,"%S")
             aux2 = aux(1:idx-1) // string(nameguess(iz,.true.)) // aux(idx+2:)
             aux = trim(aux2)
          elseif (index(aux,"%s") > 0) then
             ! the atomic symbol, lowercase
             idx = index(aux,"%s")
             aux2 = aux(1:idx-1) // string(lower(nameguess(iz,.true.))) // aux(idx+2:)
             aux = trim(aux2)
          elseif (index(aux,"%l") > 0) then
             ! the original atom label
             idx = index(aux,"%l")
             aux2 = aux(1:idx-1) // string(s%c%spc(s%c%at(i)%is)%name) // aux(idx+2:)
             aux = trim(aux2)
          else
             exit
          endif
       end do

       found = .false.
       do j = 1, nspc
          if (equal(aux,spc(j)%name) .and. s%c%spc(s%c%at(i)%is)%z == spc(j)%z) then
             found = .true.
             is(i) = j
             exit
          end if
       end do

       if (.not.found) then
          nspc = nspc + 1
          if (nspc > size(spc,1)) &
             call realloc(spc,2*nspc)
          spc(nspc)%name = trim(aux)
          spc(nspc)%z = s%c%spc(s%c%at(i)%is)%z
          spc(nspc)%qat = s%c%spc(s%c%at(i)%is)%qat
          is(i) = nspc
       end if
    end do
    call realloc(spc,nspc)

    s%c%nspc = nspc
    if (allocated(s%c%spc)) deallocate(s%c%spc)
    allocate(s%c%spc(s%c%nspc))
    s%c%spc = spc
    do i = 1, s%c%nneq
       s%c%at(i)%is = is(i)
    end do
    if (allocated(s%c%atcel)) then
       do i = 1, s%c%ncel
          s%c%atcel(i)%is = s%c%at(s%c%atcel(i)%idx)%is
       end do
    end if
    if (allocated(s%c%env%at)) then
       do i = 1, s%c%env%n
          s%c%env%at(i)%is = s%c%at(s%c%env%at(i)%idx)%is
       end do
    end if
    deallocate(is)

    ! Write the list of atomic coordinates
    if (.not.s%c%ismolecule) then
       write (uout,'("+ List of non-equivalent atoms in the unit cell (cryst. coords.): ")')
       write (uout,'("# ",7(A,X))') string("nat",3,ioj_center), &
          string("x",14,ioj_center), string("y",14,ioj_center),&
          string("z",14,ioj_center), string("name",10,ioj_center), &
          string("mult",4,ioj_center), string("Z",4,ioj_center)
       do i=1, s%c%nneq
          write (uout,'(2x,7(A,X))') &
             string(i,3,ioj_center),&
             string(s%c%at(i)%x(1),'f',length=14,decimal=10,justify=3),&
             string(s%c%at(i)%x(2),'f',length=14,decimal=10,justify=3),&
             string(s%c%at(i)%x(3),'f',length=14,decimal=10,justify=3),&
             string(s%c%spc(s%c%at(i)%is)%name,10,ioj_center), &
             string(s%c%at(i)%mult,4,ioj_center), &
             string(s%c%spc(s%c%at(i)%is)%z,4,ioj_center)
       enddo
       write (uout,*)
    else
       write (uout,'("+ List of atoms in Cartesian coordinates (",A,"): ")') iunitname0(iunit)
       write (uout,'("# ",6(A,X))') string("at",3,ioj_center), &
          string("x",16,ioj_center), string("y",16,ioj_center),&
          string("z",16,ioj_center), string("name",10,ioj_center),&
          string("Z",4,ioj_center)
       do i=1,s%c%ncel
          write (uout,'(2x,6(A,X))') &
             string(i,3,ioj_center),&
             (string((s%c%atcel(i)%r(j)+s%c%molx0(j))*dunit0(iunit),'f',length=16,decimal=10,justify=5),j=1,3),&
             string(s%c%spc(s%c%atcel(i)%is)%name,10,ioj_center),&
             string(s%c%spc(s%c%atcel(i)%is)%z,4,ioj_center)
       enddo
       write (uout,*)
    end if

  end subroutine struct_atomlabel

  !> Calculate the powder diffraction pattern for the current
  !structure.
  module subroutine struct_powder(s,line)
    use systemmod, only: system
    use global, only: fileroot, eval_next
    use tools_io, only: ferror, faterr, uout, lgetword, equal, getword, &
       fopen_write, string, ioj_center, string, fclose
    use param, only: pi
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    integer :: i, lp, lu, np, npts
    real*8 :: th2ini, th2end, lambda, fpol, sigma
    real*8, allocatable :: t(:), ih(:), th2p(:), ip(:)
    integer, allocatable :: hvecp(:,:)
    character(len=:), allocatable :: root, word
    logical :: ok, ishard

    if (s%c%ismolecule) then
       call ferror("struct_powder","POWDER cannot be used with molecules",faterr,syntax=.true.)
       return
    end if

    ! default values
    th2ini = 5d0
    th2end = 90d0
    lambda = 1.5406d0
    fpol = 0d0 ! polarization, fpol = 0.95 for synchrotron
    npts = 10001
    sigma = 0.05d0
    root = trim(fileroot) // "_xrd"
    ishard = .false.

    ! header
    write (uout,'("* POWDER: powder diffraction pattern")')
    write (uout,*)

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"th2ini")) then
          ok = eval_next(th2ini,line,lp)
          if (.not.ok) then
             call ferror('struct_powder','Incorrect TH2INI',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,"hard")) then
          ishard = .true.
       elseif (equal(word,"soft")) then
          ishard = .false.
       elseif (equal(word,"th2end")) then
          ok = eval_next(th2end,line,lp)
          if (.not.ok) then
             call ferror('struct_powder','Incorrect TH2END',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,"l").or.equal(word,"lambda")) then
          ok = eval_next(lambda,line,lp)
          if (.not.ok) then
             call ferror('struct_powder','Incorrect LAMBDA',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,"fpol")) then
          ok = eval_next(fpol,line,lp)
          if (.not.ok) then
             call ferror('struct_powder','Incorrect FPOL',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,"npts")) then
          ok = eval_next(npts,line,lp)
          if (.not.ok) then
             call ferror('struct_powder','Incorrect NPTS',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,"sigma")) then
          ok = eval_next(sigma,line,lp)
          if (.not.ok) then
             call ferror('struct_powder','Incorrect SIGMA',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,"root")) then
          root = getword(line,lp)
       elseif (len_trim(word) > 0) then
          call ferror('struct_powder','Unknown extra keyword',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    call s%c%powder(th2ini,th2end,ishard,npts,lambda,fpol,sigma,t,ih,th2p,ip,hvecp)
    np = size(th2p)

    ! write the data file
    lu = fopen_write(trim(root) // ".dat")
    write (lu,'("# ",A,A)') string("2*theta",13,ioj_center), string("Intensity",13,ioj_center)
    do i = 1, npts
       write (lu,'(A,X,A)') string(t(i),"f",15,7,ioj_center), &
          string(ih(i),"f",15,7,ioj_center)
    end do
    call fclose(lu)
    deallocate(t,ih)

    ! write the gnuplot input file
    lu = fopen_write(trim(root) // ".gnu")
    write (lu,'("set terminal postscript eps color enhanced ""Helvetica"" 25")')
    write (lu,'("set output """,A,".eps""")') trim(root)
    write (lu,*)
    do i = 1, np
       write (lu,'("set label ",A," """,A,A,A,""" at ",A,",",A," center rotate by 90 font ""Helvetica,12""")') &
          string(i), string(hvecp(1,i)), string(hvecp(2,i)), string(hvecp(3,i)), &
          string(th2p(i)*180/pi,"f"), string(min(ip(i)+4,102d0),"f")
    end do
    write (lu,*)
    write (lu,'("set xlabel ""2{/Symbol Q} (degrees)""")')
    write (lu,'("set ylabel ""Intensity (arb. units)""")')
    write (lu,'("set xrange [",A,":",A,"]")') string(th2ini,"f"), string(th2end,"f")
    write (lu,'("set style data lines")')
    write (lu,'("set grid")')
    write (lu,'("unset key")')
    write (lu,'("plot """,A,".dat"" w lines")') string(root)
    write (lu,*)
    call fclose(lu)

    ! list of peaks and intensity in output
    write(uout,'("#i  h  k  l       2*theta        Intensity ")')
    do i = 1, np
       write (uout,'(99(A,X))') string(i,3), string(hvecp(1,i),2), string(hvecp(2,i),2),&
          string(hvecp(3,i),2), string(th2p(i)*180/pi,"f",15,7,7), string(ip(i),"f",15,7,7)
    end do
    write (uout,*)

    if (allocated(t)) deallocate(t)
    if (allocated(ih)) deallocate(ih)
    if (allocated(th2p)) deallocate(th2p)
    if (allocated(ip)) deallocate(ip)
    if (allocated(hvecp)) deallocate(hvecp)

  end subroutine struct_powder

  !> Calculate the radial distribution function for the current
  !> structure.
  module subroutine struct_rdf(s,line)
    use systemmod, only: system
    use global, only: fileroot, eval_next, dunit0, iunit
    use tools_io, only: faterr, ferror, uout, lgetword, equal, fopen_write,&
       ioj_center, getword, string, fclose, isinteger
    use types, only: realloc
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    real*8 :: rini, rend
    character(len=:), allocatable :: root, word
    logical :: ok, ishard
    integer :: npts
    real*8, allocatable :: t(:), ih(:)
    integer, allocatable :: ipairs(:,:)
    integer :: lp, lu, i, npairs
    real*8 :: sigma

    ! default values
    rini = 0d0
    rend = 25d0
    root = trim(fileroot) // "_rdf"
    npts = 10001
    sigma = 0.05d0
    npairs = 0
    allocate(ipairs(2,10))
    ishard = .false.

    ! header
    write (uout,'("* RDF: radial distribution function")')
    write (uout,*)

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"rend")) then
          ok = eval_next(rend,line,lp)
          if (.not.ok) then
             call ferror('struct_rdf','Incorrect REND',faterr,line,syntax=.true.)
             return
          end if
          rend = rend / dunit0(iunit)
       elseif (equal(word,"rini")) then
          ok = eval_next(rini,line,lp)
          if (.not.ok) then
             call ferror('struct_rdf','Incorrect RINI',faterr,line,syntax=.true.)
             return
          end if
          rini = rini / dunit0(iunit)
       elseif (equal(word,"sigma")) then
          ok = eval_next(sigma,line,lp)
          if (.not.ok) then
             call ferror('struct_rdf','Incorrect SIGMA',faterr,line,syntax=.true.)
             return
          end if
          sigma = sigma / dunit0(iunit)
       elseif (equal(word,"hard")) then
          ishard = .true.
       elseif (equal(word,"soft")) then
          ishard = .false.
       elseif (equal(word,"npts")) then
          ok = eval_next(npts,line,lp)
          if (.not.ok) then
             call ferror('struct_rdf','Incorrect NPTS',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,"root")) then
          root = getword(line,lp)
       elseif (equal(word,"pair")) then
          npairs = npairs + 1
          if (npairs > size(ipairs,2)) then
             call realloc(ipairs,2,2*npairs)
          end if
          ipairs(1,npairs) = s%c%identify_spc(getword(line,lp))
          ipairs(2,npairs) = s%c%identify_spc(getword(line,lp))
          if (ipairs(1,npairs) == 0 .or. ipairs(2,npairs) == 0) then
             call ferror('struct_rdf','Unknown species in RDF/PAIR option',faterr,line,syntax=.true.)
             return
          end if
       elseif (len_trim(word) > 0) then
          call ferror('struct_rdf','Unknown extra keyword',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    call s%c%rdf(rini,rend,sigma,ishard,npts,t,ih,npairs,ipairs)

    ! write the data file
    lu = fopen_write(trim(root) // ".dat")
    write (lu,'("# ",A,A)') string("r (bohr)",13,ioj_center), string("RDF(r)",13,ioj_center)
    do i = 1, npts
       write (lu,'(A,X,A)') string(t(i),"f",15,7,ioj_center), &
          string(ih(i),"f",15,7,ioj_center)
    end do
    call fclose(lu)
    deallocate(t,ih)

    ! write the gnuplot input file
    lu = fopen_write(trim(root) // ".gnu")
    write (lu,'("set terminal postscript eps color enhanced ""Helvetica"" 25")')
    write (lu,'("set output """,A,".eps""")') trim(root)
    write (lu,*)
    write (lu,'("set xlabel ""r (bohr)""")')
    write (lu,'("set ylabel ""RDF(r)""")')
    write (lu,'("set xrange [",A,":",A,"]")') string(rini,"f"), string(rend,"f")
    write (lu,'("set style data lines")')
    write (lu,'("set grid")')
    write (lu,'("unset key")')
    write (lu,'("plot """,A,".dat"" w lines")') string(root)
    write (lu,*)
    call fclose(lu)

    if (allocated(t)) deallocate(t)
    if (allocated(ih)) deallocate(ih)

  end subroutine struct_rdf

  !> Compare two crystal structures using the powder diffraction
  !> patterns or the radial distribution functions. Uses the
  !> similarity based on cross-correlation functions proposed in
  !>   de Gelder et al., J. Comput. Chem., 22 (2001) 273.
  module subroutine struct_compare(s,line)
    use systemmod, only: system
    use crystalmod, only: crystal
    use crystalseedmod, only: struct_detect_format
    use global, only: doguess, eval_next, dunit0, iunit, iunitname0
    use tools_math, only: crosscorr_triangle, rmsd_walker
    use tools_io, only: getword, equal, faterr, ferror, uout, string, ioj_center,&
       ioj_left, string, lower
    use types, only: realloc
    use param, only: isformat_unknown
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    character(len=:), allocatable :: word, lword, tname, difstr, diftyp
    integer :: doguess0
    integer :: lp, i, j, k, n
    integer :: ns, imol, isformat, ismoli
    type(crystal), allocatable :: c(:)
    real*8 :: tini, tend, nor, h, xend, sigma, epsreduce
    real*8, allocatable :: t(:), ih(:), th2p(:), ip(:), iha(:,:)
    integer, allocatable :: hvecp(:,:)
    real*8, allocatable :: diff(:,:), xnorm(:), x1(:,:), x2(:,:)
    logical :: ok, usedot
    logical :: dopowder, ismol, laux, sorted
    character*1024, allocatable :: fname(:)
    logical, allocatable :: unique(:)

    real*8, parameter :: sigma0 = 0.05d0
    real*8, parameter :: lambda0 = 1.5406d0
    real*8, parameter :: fpol0 = 0d0
    integer, parameter :: npts = 10001
    real*8, parameter :: th2ini = 5d0
    real*8, parameter :: th2end0 = 50d0
    real*8, parameter :: rend0 = 25d0

    ! initialized
    doguess0 = doguess
    lp = 1
    ns = 0
    dopowder = .true.
    xend = -1d0
    allocate(fname(1))
    sorted = .false.
    sigma = sigma0
    epsreduce = -1d0

    ! read the input options
    doguess = 0
    imol = -1
    do while(.true.)
       word = getword(line,lp)
       lword = lower(word)
       if (equal(lword,'xend')) then
          ok = eval_next(xend,line,lp)
          if (.not.ok) then
             call ferror('struct_compare','incorrect TH2END',faterr,syntax=.true.)
             return
          end if
       elseif (equal(lword,'sigma')) then
          ok = eval_next(sigma,line,lp)
          if (.not.ok) then
             call ferror('struct_compare','incorrect SIGMA',faterr,syntax=.true.)
             return
          end if
       elseif (equal(lword,'reduce')) then
          ok = eval_next(epsreduce,line,lp)
          if (.not.ok) then
             call ferror('struct_compare','incorrect REDUCE',faterr,syntax=.true.)
             return
          end if
       elseif (equal(lword,'powder')) then
          dopowder = .true.
       elseif (equal(lword,'rdf')) then
          dopowder = .false.
          sorted = .false.
       elseif (equal(lword,'molecule')) then
          imol = 1
       elseif (equal(lword,'crystal')) then
          imol = 0
       elseif (equal(lword,'sorted')) then
          sorted = .true.
       elseif (equal(lword,'unsorted')) then
          sorted = .false.
       elseif (len_trim(word) > 0) then
          ns = ns + 1
          if (ns > size(fname)) &
             call realloc(fname,2*ns)
          fname(ns) = word
       else
          exit
       end if
    end do
    if (ns < 2) &
       call ferror('struct_compare','At least 2 structures are needed for the comparison',faterr)

    ! determine whether to use crystalmod or molecule comparison
    ismol = .true.
    usedot = .false.
    do i = 1, ns
       if (.not.equal(fname(i),".")) then
          call struct_detect_format(fname(i),isformat,laux)
          ismol = ismol .and. laux
          if (isformat == isformat_unknown) &
             call ferror("struct_compare","unknown file format: " // string(fname(i)),faterr)
          inquire(file=fname(i),exist=laux)
          if (.not.laux) &
             call ferror("struct_compare","file not found: " // string(fname(i)),faterr)
       else
          usedot = .true.
       end if
    end do
    if (imol == 0) then
       ismol = .false.
    elseif (imol == 1) then
       ismol = .true.
    end if
    if (usedot) then
       if ((s%c%ismolecule .neqv. ismol)) &
          call ferror("struct_compare","current structure (.) incompatible with molecule/crystal in compare",faterr)
       if (.not.s%c%isinit) &
          call ferror('struct_compare','Current structure is not initialized.',faterr)
    end if

    ! Read the structures and header
    write (uout,'("* COMPARE: compare structures")')
    if (ismol) then
       tname = "Molecule"
       ismoli = 1
    else
       tname = "Crystal"
       ismoli = 0
    end if
    allocate(c(ns))
    do i = 1, ns
       if (equal(fname(i),".")) then
          write (uout,'("  ",A," ",A,": <current>")') string(tname), string(i,2)
          c(i) = s%c
       else
          write (uout,'("  ",A," ",A,": ",A)') string(tname), string(i,2), string(fname(i))
          call struct_crystal_input(fname(i),ismoli,.false.,.false.,cr0=c(i))
          if (.not.c(i)%isinit) &
             call ferror("struct_compare","could not load crystal structure" // string(fname(i)),faterr)
       end if
    end do

    ! rest of the header and default variables
    if (ismol) then
       diftyp = "Molecule"
       if (sorted) then
          difstr = "RMS"
          write (uout,'("# RMS of the atomic positions in ",A)') iunitname0(iunit)
       else
          difstr = "DIFF"
          write (uout,'("# Using cross-correlated radial distribution functions (RDF).")')
          dopowder = .false.
          if (xend < 0d0) xend = rend0
       end if
    else
       diftyp = "Crystal"
       difstr = "DIFF"
       if (dopowder) then
          write (uout,'("# Using cross-correlated POWDER diffraction patterns.")')
          if (xend < 0d0) xend = th2end0
       else
          write (uout,'("# Using cross-correlated radial distribution functions (RDF).")')
          if (xend < 0d0) xend = rend0
       end if
       write (uout,'("# Two structures are exactly equal if DIFF = 0.")')
    end if

    ! allocate space for difference/rms values
    allocate(diff(ns,ns))
    diff = 1d0

    if (.not.ismol .or. (ismol.and..not.sorted)) then
       ! crystals
       allocate(iha(npts,ns))
       do i = 1, ns
          ! calculate the powder diffraction pattern
          if (dopowder) then
             call c(i)%powder(th2ini,xend,.false.,npts,lambda0,fpol0,sigma,t,ih,th2p,ip,hvecp)

             ! normalize the integral of abs(ih)
             tini = ih(1)**2
             tend = ih(npts)**2
             nor = (2d0 * sum(ih(2:npts-1)**2) + tini + tend) * (xend - th2ini) / 2d0 / real(npts-1,8)
             iha(:,i) = ih / sqrt(nor)
          else
             call c(i)%rdf(0d0,xend,sigma,.false.,npts,t,ih)
             iha(:,i) = ih
          end if
       end do
       if (allocated(t)) deallocate(t)
       if (allocated(ih)) deallocate(ih)
       if (allocated(th2p)) deallocate(th2p)
       if (allocated(ip)) deallocate(ip)
       if (allocated(hvecp)) deallocate(hvecp)

       ! self-correlation
       allocate(xnorm(ns))
       h =  (xend-th2ini) / real(npts-1,8)
       do i = 1, ns
          xnorm(i) = crosscorr_triangle(h,iha(:,i),iha(:,i),1d0)
       end do
       xnorm = sqrt(abs(xnorm))

       ! calculate the overlap between diffraction patterns
       diff = 0d0
       do i = 1, ns
          do j = i+1, ns
             diff(i,j) = max(1d0 - crosscorr_triangle(h,iha(:,i),iha(:,j),1d0) / xnorm(i) / xnorm(j),0d0)
             diff(j,i) = diff(i,j)
          end do
       end do
       deallocate(xnorm)
    else
       ! molecules
       diff = 0d0
       do i = 1, ns
          do j = i+1, ns
             if (c(i)%ncel == c(j)%ncel) then
                n = c(i)%ncel
                allocate(x1(3,n),x2(3,n))
                do k = 1, n
                   x1(:,k) = c(i)%atcel(k)%r + c(i)%molx0
                   x2(:,k) = c(j)%atcel(k)%r + c(j)%molx0
                end do
                diff(i,j) = rmsd_walker(x1,x2)
                deallocate(x1,x2)
             else
                diff(i,j) = -1d0
             end if
             diff(j,i) = diff(i,j)
          end do
       end do
       diff = diff * dunit0(iunit)
    endif

    ! write output
    if (ns == 2) then
       write (uout,'("+ ",A," = ",A)') string(difstr), string(diff(1,2),'e',12,6)
    else
       do i = 0, (ns-1)/5
          write (uout,'(99(A,X))') string(diftyp,15,ioj_center), &
             (string(c(5*i+j)%file,15,ioj_center),j=1,min(5,ns-i*5))
          write (uout,'(99(A,X))') string(difstr,15,ioj_center), &
             (string(5*i+j,15,ioj_center),j=1,min(5,ns-i*5))
          do j = 1, ns
             write (uout,'(2X,99(A,X))') string(c(j)%file,15,ioj_left), &
                (string(diff(j,5*i+k),'f',15,7,3),k=1,min(5,ns-i*5))
          end do
          write (uout,*)
       end do
    endif
    write (uout,*)

    ! reduce
    if (epsreduce > 0d0) then
       allocate(unique(ns))
       unique = .true.
       do i = ns, 1, -1
          do j = 1, i-1
             if (diff(i,j) < epsreduce) then
                unique(i) = .false.
                exit
             end if
          end do
       end do

       write (uout,'("+ List of unique structures (",A,"): ")') string(count(unique))
       do i = 1, ns
          if (unique(i)) write (uout,'(A,": ",A)') string(i), trim(c(i)%file)
       end do
       write (uout,*)

       write (uout,'("+ List of repeated structures (",A,"): ")') string(ns-count(unique))
       do i = 1, ns
          if (.not.unique(i)) write (uout,'(A,": ",A)') string(i), trim(c(i)%file)
       end do
       write (uout,*)

       deallocate(unique)
    end if

    ! clean up
    deallocate(diff)
    doguess = doguess0

  end subroutine struct_compare

  !> Calculate the atomic environment of a point or all the
  !> non-equivalent atoms in the unit cell.
  module subroutine struct_environ(s,line)
    use systemmod, only: system
    use environmod, only: environ
    use global, only: eval_next, dunit0, iunit, iunitname0
    use tools_io, only: string, lgetword, equal, ferror, faterr, noerr, string, uout,&
       ioj_right, ioj_center, zatguess, isinteger
    use param, only: bohrtoa, icrd_crys
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    real*8 :: up2d
    integer :: nat, lvec(3)
    integer, allocatable :: eid(:), ishell(:)
    real*8, allocatable :: dist(:)
    integer :: lp, lp2, ierr
    character(len=:), allocatable :: word
    real*8 :: x0(3), x0in(3)
    logical :: doatoms, ok, groupshell
    logical, allocatable :: isdone(:)
    integer :: i, j, k, l, idx
    type(environ), target :: eaux
    type(environ), pointer :: eptr

    integer :: iat, iby, iat_mode, iby_mode
    integer, parameter :: inone = 0
    integer, parameter :: iznuc = 1
    integer, parameter :: iid = 2
    integer, parameter :: iidcel = 3

    up2d = 5d0 / bohrtoa

    x0 = 0d0
    doatoms = .true.
    iat = 0
    iat_mode = inone
    iby = 0
    iby_mode = inone
    groupshell = .false.

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"dist")) then
          ok = eval_next(up2d,line,lp)
          if (.not.ok) then
             call ferror('struct_environ','Wrong DIST syntax',faterr,line,syntax=.true.)
             return
          end if
          up2d = up2d / dunit0(iunit)
       elseif (equal(word,"point")) then
          ok = eval_next(x0(1),line,lp)
          ok = ok .and. eval_next(x0(2),line,lp)
          ok = ok .and. eval_next(x0(3),line,lp)
          if (.not.ok) then
             call ferror('struct_environ','Wrong POINT syntax',faterr,line,syntax=.true.)
             return
          end if
          doatoms = .false.
          x0in = x0
          if (s%c%ismolecule) &
             x0 = s%c%c2x(x0 / dunit0(iunit) - s%c%molx0)
       elseif (equal(word,"atom")) then
          doatoms = .true.
          lp2 = lp
          word = lgetword(line,lp)
          iat = zatguess(word)
          if (iat < 0) then
             lp = lp2
             ok = isinteger(iat,line,lp)
             if (.not.ok) &
                call ferror('struct_environ','Syntax error in ENVIRON/ATOM',faterr,line,syntax=.true.)
             iat_mode = iid
          else
             iat_mode = iznuc
          end if
       elseif (equal(word,"celatom")) then
          ok = isinteger(iat,line,lp)
          if (.not.ok) &
             call ferror('struct_environ','Syntax error in ENVIRON/CELATOM',faterr,line,syntax=.true.)
          iat_mode = iidcel
          doatoms = .true.
       elseif (equal(word,"by")) then
          lp2 = lp
          word = lgetword(line,lp)
          iby = zatguess(word)
          if (iby < 0) then
             lp = lp2
             ok = isinteger(iby,line,lp)
             if (.not.ok) &
                call ferror('struct_environ','Syntax error in ENVIRON/BY',faterr,line,syntax=.true.)
             iby_mode = iid
          else
             iby_mode = iznuc
          end if
       elseif (equal(word,"shell").or.equal(word,"shells")) then
          groupshell = .true.
       elseif (len_trim(word) > 0) then
          call ferror('struct_environ','Unknown extra keyword',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    write (uout,'("* ENVIRON")')
    eptr => s%c%env
    if (doatoms) then
       allocate(isdone(s%c%nneq))
       isdone = .false.
       do i = 1, s%c%ncel
          idx = s%c%atcel(i)%idx
          if (iat_mode == iid .and. idx /= iat .or. isdone(idx)) cycle
          if (iat_mode == iznuc .and. s%c%spc(s%c%at(idx)%is)%z /= iat .or. isdone(idx)) cycle
          if (iat_mode == iidcel .and. i /= iat) cycle
          isdone(idx) = .true.

          if (iby_mode == iid) then
             call eptr%list_near_atoms(s%c%atcel(i)%x,icrd_crys,.true.,nat,ierr,eid,dist,&
                lvec,ishell,up2d=up2d,nid0=iby,nozero=.true.)
          elseif (iby_mode == iznuc) then
             call eptr%list_near_atoms(s%c%atcel(i)%x,icrd_crys,.true.,nat,ierr,eid,dist,&
                lvec,ishell,up2d=up2d,iz0=iby,nozero=.true.)
          else
             call eptr%list_near_atoms(s%c%atcel(i)%x,icrd_crys,.true.,nat,ierr,eid,dist,&
                lvec,ishell,up2d=up2d,nozero=.true.)
          end if
          if (ierr > 0 .and..not.s%c%ismolecule) then
             call ferror('struct_environ','very large distance cutoff, calculating a new environment',noerr)
             call eaux%build(s%c%ismolecule,s%c%nspc,s%c%spc,s%c%ncel,s%c%atcel,s%c%m_xr2c,s%c%m_x2xr,s%c%m_x2c,up2d)
             if (iby_mode == iid) then
                call eaux%list_near_atoms(s%c%atcel(i)%x,icrd_crys,.true.,nat,ierr,eid,dist,&
                   lvec,ishell,up2d=up2d,nid0=iby,nozero=.true.)
             elseif (iby_mode == iznuc) then
                call eaux%list_near_atoms(s%c%atcel(i)%x,icrd_crys,.true.,nat,ierr,eid,dist,&
                   lvec,ishell,up2d=up2d,iz0=iby,nozero=.true.)
             else
                call eaux%list_near_atoms(s%c%atcel(i)%x,icrd_crys,.true.,nat,ierr,eid,dist,&
                   lvec,ishell,up2d=up2d,nozero=.true.)
             end if
             if (ierr > 0) &
                call ferror('struct_environ','unknown error calculating atom environment',faterr)
             eptr => eaux
          end if

          write (uout,'("+ Environment of atom ",A," (spc=",A,", nid=",A,") at ",3(A,X))') &
             string(i), string(s%c%spc(s%c%at(idx)%is)%name), string(idx), &
             (string(s%c%atcel(i)%x(j),'f',length=10,decimal=6),j=1,3)

          if (groupshell) then
             call output_by_shell()
          else
             call output_by_distance()
          end if
          if (iat_mode == iid) exit
       end do
       deallocate(isdone)
    else
       if (iby_mode == iid) then
          call eptr%list_near_atoms(x0,icrd_crys,.true.,nat,ierr,eid,dist,lvec,ishell,up2d=up2d,nid0=iby)
       elseif (iby_mode == iznuc) then
          call eptr%list_near_atoms(x0,icrd_crys,.true.,nat,ierr,eid,dist,lvec,ishell,up2d=up2d,iz0=iby)
       else
          call eptr%list_near_atoms(x0,icrd_crys,.true.,nat,ierr,eid,dist,lvec,ishell,up2d=up2d)
       end if
       if (ierr > 0 .and..not.s%c%ismolecule) then
          call ferror('struct_environ','very large distance cutoff, calculating a new environment',noerr)
          call eaux%build(s%c%ismolecule,s%c%nspc,s%c%spc,s%c%ncel,s%c%atcel,s%c%m_xr2c,s%c%m_x2xr,s%c%m_x2c,up2d)
          if (iby_mode == iid) then
             call eaux%list_near_atoms(x0,icrd_crys,.true.,nat,ierr,eid,dist,lvec,ishell,up2d=up2d,nid0=iby)
          elseif (iby_mode == iznuc) then
             call eaux%list_near_atoms(x0,icrd_crys,.true.,nat,ierr,eid,dist,lvec,ishell,up2d=up2d,iz0=iby)
          else
             call eaux%list_near_atoms(x0,icrd_crys,.true.,nat,ierr,eid,dist,lvec,ishell,up2d=up2d)
          end if
          if (ierr > 0) &
             call ferror('struct_environ','unknown error calculating point environment',faterr)
          eptr => eaux
       end if

       write (uout,'("+ Environment of point ",3(A,X))') (string(x0in(j),'f',length=10,decimal=6),j=1,3)

       if (groupshell) then
          call output_by_shell()
       else
          call output_by_distance()
       end if
    end if

  contains
    subroutine output_by_distance()
      integer :: mshel, eidx, cidx, nidx
      real*8 :: xx(3)

      mshel = maxval(ishell)
      write (uout,'("# Up to distance (",A,"): ",A)') iunitname0(iunit), string(up2d*dunit0(iunit),'f',length=10,decimal=6)
      write (uout,'("# Number of atoms in the environment: ",A)') string(nat)
      write (uout,'("# Number of atomic shells in the environment: ",A)') string(mshel)
      write (uout,'("# nid = non-equivalent list atomic ID. id = complete list atomic ID plus lattice vector (lvec).")')
      write (uout,'("# name = atomic name (symbol). spc = atomic species. dist = distance. shel = shell ID.")')
      if (s%c%ismolecule) then
         write (uout,'("#nid   id      lvec     name   spc  dist(",A,") shel          Coordinates (",A,") ")') &
            iunitname0(iunit), iunitname0(iunit)
      else
         write (uout,'("#nid   id      lvec     name   spc  dist(",A,") shel      Coordinates (cryst. coord.) ")') iunitname0(iunit)
      end if
      do j = 1, nat
         eidx = eid(j)
         nidx = eptr%at(eidx)%idx
         cidx = eptr%at(eidx)%cidx
         if (s%c%ismolecule) then
            xx = (eptr%at(eidx)%r + s%c%molx0) * dunit0(iunit)
         else
            xx = eptr%xr2x(eptr%at(eidx)%x) + lvec
         end if

         write (uout,'(2X,2(A,X),"(",A,X,A,X,A,")",99(X,A))') string(nidx,4,ioj_center), string(cidx,4,ioj_center),&
            (string(eptr%at(eidx)%lvec(k)+lvec(k),2,ioj_right),k=1,3), string(s%c%spc(eptr%at(eidx)%is)%name,7,ioj_center),&
            string(eptr%at(eidx)%is,2,ioj_right), string(dist(j)*dunit0(iunit),'f',12,6,4), string(ishell(j),3,ioj_center),&
            (string(xx(k),'f',12,8,4),k=1,3)
      end do
      write (uout,*)
    end subroutine output_by_distance

    subroutine output_by_shell()
      integer :: mshel, eidx, cidx, nidx, nneig, ishl0
      real*8 :: xx(3)

      mshel = maxval(ishell)
      write (uout,'("# Up to distance (",A,"): ",A)') iunitname0(iunit), string(up2d*dunit0(iunit),'f',length=10,decimal=6)
      write (uout,'("# Number of atoms in the environment: ",A)') string(nat)
      write (uout,'("# Number of atomic shells in the environment: ",A)') string(mshel)
      write (uout,'("# ishl = shell ID. nneig = number of neighbors in the shell. nid = non-equivalent list atomic ID.")')
      write (uout,'("# name = atomic name (symbol). spc = atomic species. dist = distance. Rest of fields are for a single")')
      write (uout,'("# representative of the shell: id = complete list atomic ID plus lattice vector (lvec) and coordinates. ")')
      if (s%c%ismolecule) then
         write (uout,'("#ishl nneig nid   name   spc  dist(",A,")  id     lvec            Coordinates (",A,") ")') &
            iunitname0(iunit), iunitname0(iunit)
      else
         write (uout,'("#ishl nneig nid   name   spc  dist(",A,")  id     lvec        Coordinates (cryst. coord.) ")')&
            iunitname0(iunit)
      end if
      k = 1
      main: do j = 1, mshel
         ishl0 = k
         do while (ishell(k) == j)
            k = k + 1
            if (k > nat) exit
         end do
         if (k == 1) exit
         nneig = k - ishl0

         eidx = eid(k-1)
         nidx = eptr%at(k-1)%idx
         cidx = eptr%at(k-1)%cidx
         if (s%c%ismolecule) then
            xx = (eptr%at(eidx)%r + s%c%molx0) * dunit0(iunit)
         else
            xx = eptr%xr2x(eptr%at(eidx)%x) + lvec
         end if

         write (uout,'(7(A,X),"(",3(A,X),")",99(A,X))') string(j,5,ioj_center),&
            string(nneig,5,ioj_center), string(nidx,4,ioj_center),&
            string(s%c%spc(eptr%at(eidx)%is)%name,7,ioj_center), string(eptr%at(eidx)%is,2,ioj_right),&
            string(dist(k-1)*dunit0(iunit),'f',12,6,4), string(cidx,4,ioj_center),&
            (string(eptr%at(eidx)%lvec(l)+lvec(l),2,ioj_right),l=1,3), (string(xx(l),'f',12,8,4),l=1,3)
      end do main
      write (uout,*)
    end subroutine output_by_shell

  end subroutine struct_environ

  !> Calculate the coordination numbers of all atoms.
  module subroutine struct_coord(s,line)
    use systemmod, only: system
    use environmod, only: environ
    use global, only: bondfactor, eval_next
    use tools_io, only: ferror, faterr, zatguess, lgetword, equal, isinteger, ioj_center,&
       ioj_left, ioj_right, uout, string
    use param, only: atmcov, icrd_crys
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    character(len=:), allocatable :: word
    integer :: lp, i, j, k
    real*8, allocatable :: rad(:)
    real*8 :: fac, dd
    logical :: ok
    integer :: nat, ierr
    integer, allocatable :: eid(:), coord2(:,:), coord2sp(:,:), coord3(:,:,:), coord3sp(:,:,:)
    real*8, allocatable :: up2dsp(:,:)
    type(environ), pointer :: eptr

    ! allocate the default radii
    fac = bondfactor
    allocate(rad(s%c%nspc))
    rad = 0d0
    do i = 1, s%c%nspc
       if (s%c%spc(i)%z > 0) then
          rad(i) = atmcov(s%c%spc(i)%z)
       end if
    end do

    ! parse the input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"dist")) then
          ok = eval_next(dd,line,lp)
          if (.not.ok) then
             call ferror('struct_coord','Wrong DIST keyword',faterr,line,syntax=.true.)
             return
          end if
          fac = 1d0
          rad = 0.5d0 * dd
       elseif (equal(word,"fac")) then
          ok = eval_next(fac,line,lp)
          if (.not.ok) then
             call ferror('struct_coord','Wrong FAC keyword',faterr,line,syntax=.true.)
             return
          end if
       elseif (len_trim(word) > 0) then
          call ferror('struct_coord','Unknown extra keyword',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    ! some output
    write (uout,'("* COORD: calculation of coordination numbers")')
    write (uout,'("+ Atomic radii for all species")')
    write (uout,'("# Atoms i and j are coordinated if distance(i,j) <= fac*(radi+radj), fac = ",A)') &
       string(fac,'f',length=5,decimal=2,justify=ioj_left)
    write (uout,'("# ",99(A,X))') string("spc",3,ioj_center), &
       string("Z",3,ioj_center), string("name",7,ioj_center),&
       string("rad",length=5,justify=ioj_center)
    do i = 1, s%c%nspc
       write (uout,'("  ",99(A,X))') string(i,3,ioj_center), &
          string(s%c%spc(i)%z,3,ioj_center), string(s%c%spc(i)%name,7,ioj_center),&
          string(rad(i),'f',length=5,decimal=2,justify=ioj_right)
    end do
    write (uout,*)

    ! calculate the coordination numbers (per atom)
    allocate(up2dsp(s%c%nspc,2),coord2(s%c%nneq,s%c%nspc))
    up2dsp = 0d0
    coord2 = 0
    eptr => s%c%env
    do i = 1, s%c%nneq
       up2dsp(:,2) = rad + rad(s%c%at(i)%is)
       call eptr%list_near_atoms(s%c%at(i)%x,icrd_crys,.false.,nat,ierr,eid,up2dsp=up2dsp,nozero=.true.)
       do j = 1, nat
          coord2(i,eptr%at(eid(j))%is) = coord2(i,eptr%at(eid(j))%is) + 1
       end do
    end do
    deallocate(rad,up2dsp)

    ! output coordination numbers (per non-equivalent atom)
    write (uout,'("+ Pair coordination numbers (per non-equivalent atom in the cell)")')
    write (uout,'("# id = non-equivalent atom ID. mult = multiplicity. rest = atomic species (by name).")')
    write (uout,'("# ",99(A,X))') string("nid",4,ioj_center), string("name",7,ioj_center), &
       string("mult",5,ioj_center), (string(s%c%spc(j)%name,5,ioj_left),j=1,s%c%nspc), "total"
    do i = 1, s%c%nneq
       write (uout,'(2X,99(A,X))') string(i,4,ioj_center), string(s%c%spc(s%c%at(i)%is)%name,7,ioj_center), &
          string(s%c%at(i)%mult,5,ioj_center), (string(coord2(i,j),5,ioj_center),j=1,s%c%nspc),&
          string(sum(coord2(i,1:s%c%nspc)),5,ioj_center)
    end do
    write (uout,*)

    ! calculate the coordination numbers (per species)
    allocate(coord2sp(s%c%nspc,s%c%nspc))
    coord2sp = 0
    do i = 1, s%c%nneq
       do j = 1, s%c%nspc
          coord2sp(s%c%at(i)%is,j) = coord2sp(s%c%at(i)%is,j) + coord2(i,j) * s%c%at(i)%mult
       end do
    end do

    write (uout,'("+ Pair coordination numbers (per species)")')
    write (uout,'("# ",99(A,X))') string("spc",8,ioj_center), (string(s%c%spc(j)%name,5,ioj_center),j=1,s%c%nspc)
    do i = 1, s%c%nspc
       write (uout,'(2X,99(A,X))') string(i,3,ioj_center), string(s%c%spc(i)%name,5,ioj_center), &
          (string((coord2sp(i,j)+coord2sp(j,i))/2,5,ioj_center),j=1,s%c%nspc)
    end do
    write (uout,*)
    deallocate(coord2sp)

    ! calculate the number of triplets
    allocate(coord3(s%c%nneq,s%c%nspc,s%c%nspc))
    coord3 = 0
    do i = 1, s%c%nneq
       do j = 1, s%c%nspc
          do k = 1, s%c%nspc
             if (j == k) then
                coord3(i,j,k) = coord3(i,j,k) + coord2(i,j) * (coord2(i,k)-1) / 2
             else
                coord3(i,j,k) = coord3(i,j,k) + coord2(i,j) * coord2(i,k)
             end if
          end do
       end do
    end do

    write (uout,'("+ Triplet coordination numbers (per non-equivalent atom in the cell)")')
    write (uout,'("# Y runs over atoms in the cell: nid = non-equivalent atom ID. mult = multiplicity.")')
    write (uout,'("#  ---    Y    ---     X     Z")')
    write (uout,'("# nid   name   mult   spc   spc  X-Y-Z")')
    do i = 1, s%c%nneq
       do j = 1, s%c%nspc
          do k = j, s%c%nspc
             write (uout,'(2X,99(A,X))') string(i,4,ioj_center), string(s%c%spc(s%c%at(i)%is)%name,7,ioj_center), &
                string(s%c%at(i)%mult,5,ioj_center), string(s%c%spc(j)%name,5,ioj_center), string(s%c%spc(k)%name,5,ioj_center),&
                string((coord3(i,j,k)+coord3(i,k,j))/2,5,ioj_center)
          end do
       end do
    end do
    write (uout,*)

    ! calculate the triplet coordination numbers (per species)
    allocate(coord3sp(s%c%nspc,s%c%nspc,s%c%nspc))
    coord3sp = 0
    do i = 1, s%c%nneq
       do j = 1, s%c%nspc
          do k = 1, s%c%nspc
             coord3sp(s%c%at(i)%is,j,k) = coord3sp(s%c%at(i)%is,j,k) + coord3(i,j,k) * s%c%at(i)%mult
          end do
       end do
    end do

    write (uout,'("+ Triplet coordination numbers (per species)")')
    write (uout,'("#   Y     X     Z   X-Y-Z")')
    do i = 1, s%c%nspc
       do j = 1, s%c%nspc
          do k = j, s%c%nspc
             write (uout,'(2X,99(A,X))') string(s%c%spc(j)%name,5,ioj_center), string(s%c%spc(i)%name,5,ioj_center), &
                string(s%c%spc(k)%name,5,ioj_center), string((coord3sp(i,j,k)+coord3sp(i,k,j))/2,5,ioj_center)
          end do
       end do
    end do
    write (uout,*)

    deallocate(coord3,coord3sp)

  end subroutine struct_coord

  !> Calculate the coordination polyedra.
  module subroutine struct_polyhedra(s,line)
    use iso_c_binding, only: c_int, c_double
    use systemmod, only: system
    use tools_io, only: equali, zatguess, ferror, faterr, getword, uout, string, ioj_left, ioj_center
    use tools_math, only: mixed
    use global, only: bondfactor, eval_next, dunit0, iunit, iunitname0
    use environmod, only: environ
    ! use tools_io, only: ferror, faterr, zatguess, lgetword, equal, isinteger, ioj_center,&
    !    ioj_left, ioj_right, uout, string
    use param, only: atmcov, icrd_crys
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    character(len=:), allocatable :: at1, at2
    integer :: lp, is1, is2, iz1, iz2, ierr, lvec(3)
    real*8 :: rdum, rmin, rmax, vol, xp1(3), xp2(3), xp3(3)
    logical :: ok
    integer, allocatable :: eid(:)
    integer :: i, j
    real*8, allocatable :: dist(:)
    integer(c_int) :: nat, nf
    real(c_double) :: x0(3)
    real(c_double), allocatable :: xstar(:,:)
    integer(c_int), allocatable :: iface(:,:)
    type(environ), pointer :: eptr

    interface
       ! The definitions and documentation for these functions are in doqhull.c
       subroutine runqhull_basintriangulate_step1(n,x0,xvert,nf) bind(c)
         import c_int, c_double
         integer(c_int), value :: n
         real(c_double) :: x0(3)
         real(c_double) :: xvert(3,n)
         integer(c_int) :: nf
       end subroutine runqhull_basintriangulate_step1
       subroutine runqhull_basintriangulate_step2(nf,iface) bind(c)
         import c_int, c_double
         integer(c_int), value :: nf
         integer(c_int) :: iface(3,nf)
       end subroutine runqhull_basintriangulate_step2
    end interface

    ! Initialize
    lp = 1
    eptr => s%c%env

    ! Literal interpretation of the species
    at1 = getword(line,lp)
    at2 = getword(line,lp)
    is1 = 0
    is2 = 0
    do i = 1, s%c%nspc
       if (is1 == 0) then
          if (equali(at1,s%c%spc(i)%name)) &
             is1 = i
       end if
       if (is2 == 0) then
          if (equali(at2,s%c%spc(i)%name)) &
             is2 = i
       end if
    end do

    ! If not found, convert to atomic number and try that instead
    if (is1 == 0) then
       iz1 = zatguess(at1)
    else
       iz1 = s%c%spc(is1)%z
    end if
    if (is2 == 0) then
       iz2 = zatguess(at2)
    else
       iz2 = s%c%spc(is2)%z
    end if
    if (iz1 <= 0) &
       call ferror("struct_polyhedra","unrecognized atomic species: " // at1,faterr)
    if (iz2 <= 0) &
       call ferror("struct_polyhedra","unrecognized atomic species: " // at2,faterr)

    ! default distance range
    rmin = 0d0
    rmax = (atmcov(iz1) + atmcov(iz2)) * bondfactor
    ok = eval_next(rdum,line,lp)
    if (ok) rmax = rdum / dunit0(iunit)
    ok = eval_next(rdum,line,lp)
    if (ok) then
       rmin = rmax
       rmax = rdum / dunit0(iunit)
    end if

    write (uout,'("* POLYHEDRA: calculation of coordination polyhedra")')
    if (is1 == 0) then
       write (uout,'("  Center of the polyhedra: Z = ",A)') string(iz1)
    else
       write (uout,'("  Center of the polyhedra: ",A)') trim(s%c%spc(is1)%name)
    end if
    if (is2 == 0) then
       write (uout,'("  Vertex of the polyhedra: Z = ",A)') string(iz2)
    else
       write (uout,'("  Vertex of the polyhedra: ",A)') trim(s%c%spc(is2)%name)
    end if
    write (uout,'("  Distance range(",A,"): ",A," to ",A)') string(iunitname0(iunit)),&
       string(rmin*dunit0(iunit),'f',decimal=4), string(rmax*dunit0(iunit),'f',decimal=4)
    write (uout, '("# nid = non-equivalent atom ID. at = atomic name (symbol)")')
    write (uout, '("# cryst coords = crystallographic coordinates. nv = number of vertices.")')
    write (uout, '("# rmin = minimum vertex distance (",A,"), rmax = maximum vertex distance (",A,").")') &
       string(iunitname0(iunit)), string(iunitname0(iunit))
    write (uout, '("# nf = number of faces. volume = polyhedron volume (",A,"^3).")') string(iunitname0(iunit))
    write (uout,'("#nid at mult   ----- Cryst. coords. -----     nv   rmin       rmax      nf   volume")')
    do i = 1, s%c%nneq
       if (is1 == 0) then
          if (s%c%spc(s%c%at(i)%is)%z /= iz1) cycle
       else
          if (s%c%at(i)%is /= is1) cycle
       end if

       ! find the environment
       if (is2 /= 0) then
          ! by species
          call eptr%list_near_atoms(s%c%at(i)%x,icrd_crys,.true.,nat,ierr,eid=eid,dist=dist,&
             lvec=lvec,up2d=rmax,ispc0=is2,nozero=.true.)
       else
          ! by z
          call eptr%list_near_atoms(s%c%at(i)%x,icrd_crys,.true.,nat,ierr,eid=eid,dist=dist,&
             up2d=rmax,iz0=iz2,nozero=.true.)
       end if
       if (nat <= 2) cycle

       ! project on a sphere and triangulate the convex polyhedron
       if (allocated(xstar)) deallocate(xstar)
       allocate(xstar(3,nat))
       x0 = s%c%at(i)%r
       do j = 1, nat
          xstar(:,j) = eptr%xr2x(eptr%at(eid(j))%x) + lvec
          xstar(:,j) = s%c%x2c(xstar(:,j))
       end do
       call runqhull_basintriangulate_step1(nat,x0,xstar,nf)
       if (allocated(iface)) deallocate(iface)
       allocate(iface(3,nf))
       call runqhull_basintriangulate_step2(nf,iface)

       ! calculate the polyhedron volume
       vol = 0d0
       do j = 1, nf
          xp1 = xstar(:,iface(1,j)) - x0
          xp2 = xstar(:,iface(2,j)) - x0
          xp3 = xstar(:,iface(3,j)) - x0
          vol = vol + abs(mixed(xp1,xp2,xp3)) / 6d0
       end do

       write (uout,'(99(A,X))') string(i,3,ioj_left), &
          string(s%c%spc(s%c%at(i)%is)%name,4,ioj_center),string(s%c%at(i)%mult,3),&
          (string(s%c%at(i)%x(j),'f',length=10,decimal=6),j=1,3),&
          string(nat,3,ioj_center), string(minval(dist)*dunit0(iunit),'f',length=10,decimal=6),&
          string(maxval(dist)*dunit0(iunit),'f',length=10,decimal=6), string(nf,3,ioj_center),&
          string(vol*dunit0(iunit)**3,'f',length=10,decimal=6)
    end do
    write (uout,*)

  end subroutine struct_polyhedra

  !> Calculate the packing ratio of the crystal.
  module subroutine struct_packing(s,line)
    use systemmod, only: system
    use global, only: eval_next
    use tools_io, only: ferror, faterr, uout, lgetword, equal, string
    use param, only: atmvdw, atmcov
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    integer :: lp
    logical :: ok
    character(len=:), allocatable :: word
    real*8 :: prec
    real*8 :: vout
    integer :: whichuse = 0

    if (s%c%ismolecule) then
       call ferror("critic2","PACKING cannot be used with molecules",faterr,syntax=.true.)
       return
    end if

    ! default values
    prec = 1d-2
    whichuse = 0 ! 0 = nnm, 1 = vdw, 2 = cov

    ! header
    write (uout,'("* PACKING")')

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"vdw")) then
          whichuse = 1
       elseif (equal(word,"cov")) then
          whichuse = 2
       elseif (equal(word,"prec")) then
          ok = eval_next(prec,line,lp)
          if (.not.ok) then
             call ferror('struct_packing','Wrong PREC syntax',faterr,line,syntax=.true.)
             return
          end if
       elseif (len_trim(word) > 0) then
          call ferror('struct_packing','Unknown extra keyword',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    if (whichuse == 0) then
       write (uout,'("+ Packing ratio (%): ",A)') string(s%c%get_pack_ratio(),'f',10,4)
    else
       if (whichuse == 1) then
          vout = s%c%vdw_volume(prec,atmvdw)
       else
          vout = s%c%vdw_volume(prec,atmcov)
       end if
       write (uout,'("+ Van der Waals volume: ",A," +- ",A)') &
          string(vout,'f',decimal=6), string(prec*vout,'f',decimal=6)
       write (uout,'("+ Interstitial volume (outside vdw spheres): ",A," +- ",A)') &
          string(s%c%omega-vout,'f',decimal=6), string(prec*vout,'f',decimal=6)
       write (uout,'("+ Cell volume: ",A)') string(s%c%omega,'f',decimal=6)
       write (uout,'("+ Packing ratio (%): ",A," +- ",A)') string(vout/s%c%omega*100d0,'f',decimal=6), &
          string(prec*vout/s%c%omega*100d0,'f',decimal=6)
    end if
    write (uout,*)

  end subroutine struct_packing

  !> Calculate the van der Waals volume of a crystal or molecule.
  module subroutine struct_vdw(s,line)
    use systemmod, only: system
    use tools_io, only: ferror, faterr, uout, lgetword, equal, string
    use global, only: eval_next
    type(system), intent(in) :: s
    character*(*), intent(in) :: line

    integer :: lp
    logical :: ok
    character(len=:), allocatable :: word
    real*8 :: vvdw
    real*8 :: prec

    ! default values
    prec = 1d-2

    ! header
    write (uout,'("* VDW")')

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"prec")) then
          ok = eval_next(prec,line,lp)
          if (.not.ok) then
             call ferror('struct_packing','Wrong PREC syntax in VDW',faterr,line,syntax=.true.)
             return
          end if
       elseif (len_trim(word) > 0) then
          call ferror('struct_packing','Unknown extra keyword',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    ! calculate vdw volume
    vvdw = s%c%vdw_volume(prec)

    ! output
    write (uout,'("+ Requested sigma_{Vvdw}/Vvdw: ",A)') string(prec,'e',decimal=4)
    write (uout,'("+ Van der Waals volume (Vvdw): ",A," +- ",A)') &
       string(vvdw,'f',decimal=6), string(prec*vvdw,'f',decimal=6)
    if (.not.s%c%ismolecule) then
       write (uout,'("+ Interstitial volume (outside vdw spheres): ",A," +- ",A)') &
          string(s%c%omega-vvdw,'f',decimal=6), string(prec*vvdw,'f',decimal=6)
       write (uout,'("+ Cell volume: ",A)') string(s%c%omega,'f',decimal=6)
       write (uout,'("+ Packing ratio (%): ",A," +- ",A)') string(vvdw/s%c%omega*100d0,'f',decimal=6), &
          string(prec*vvdw/s%c%omega*100d0,'f',decimal=6)
    end if
    write (uout,*)

  end subroutine struct_vdw

  !> Build a new crystal from the current crystal by cell transformation
  module subroutine struct_newcell(s,line,verbose)
    use systemmod, only: system
    use global, only: eval_next
    use tools_math, only: matinv
    use tools_io, only: uout, ferror, faterr, lgetword, equal, string
    type(system), intent(inout) :: s
    character*(*), intent(in) :: line
    logical, intent(in) :: verbose

    character(len=:), allocatable :: word
    logical :: ok, doprim, doforce, changed
    integer :: lp, lp2, dotyp, i
    real*8 :: x0(3,3), t0(3), rdum(4)
    logical :: doinv, dorefine

    if (s%c%ismolecule) then
       call ferror("struct_newcell","NEWCELL cannot be used with molecules",faterr,syntax=.true.)
       return
    end if

    write (uout,'("* Transformation to a new unit cell (NEWCELL)")')
    write (uout,*)

    ! transform to the primitive?
    lp = 1
    doprim = .false.
    doforce = .false.
    dorefine = .false.
    dotyp = 0
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"standard")) then
          dotyp = 1
          doprim = .false.
       elseif (equal(word,"primitive")) then
          doforce = .false.
          dotyp = 1
          doprim = .true.
       elseif (equal(word,"primstd")) then
          doforce = .true.
          dotyp = 1
          doprim = .true.
       elseif (equal(word,"niggli")) then
          dotyp = 2
       elseif (equal(word,"delaunay")) then
          dotyp = 3
       elseif (equal(word,"refine")) then
          dorefine = .true.
       else
          lp = 1
          exit
       end if
    end do

    t0 = 0d0
    x0 = 0d0
    if (dotyp == 1) then
       x0 = s%c%cell_standard(doprim,doforce,dorefine)
       changed = any(abs(x0) > 1d-5)
    elseif (dotyp == 2) then
       x0 = s%c%cell_niggli()
       changed = any(abs(x0) > 1d-5)
    elseif (dotyp == 3) then
       x0 = s%c%cell_delaunay()
       changed = any(abs(x0) > 1d-5)
    else
       ! read the vectors from the input
       ok = eval_next(rdum(1),line,lp)
       ok = ok .and. eval_next(rdum(2),line,lp)
       ok = ok .and. eval_next(rdum(3),line,lp)
       if (.not.ok) then
          call ferror("struct_newcell","Wrong syntax in NEWCELL",faterr,line,syntax=.true.)
          return
       end if

       lp2 = lp
       ok = eval_next(rdum(4),line,lp)
       if (ok) then
          x0(:,1) = rdum(1:3)
          x0(1,2) = rdum(4)
          ok = eval_next(x0(2,2),line,lp)
          ok = ok .and. eval_next(x0(3,2),line,lp)
          ok = ok .and. eval_next(x0(1,3),line,lp)
          ok = ok .and. eval_next(x0(2,3),line,lp)
          ok = ok .and. eval_next(x0(3,3),line,lp)
          if (.not.ok) then
             call ferror("struct_newcell","Wrong syntax in NEWCELL",faterr,line,syntax=.true.)
             return
          end if
       else
          lp = lp2
          do i = 1, 3
             x0(i,i) = rdum(i)
          end do
       end if

       doinv = .false.
       do while (.true.)
          word = lgetword(line,lp)
          if (equal(word,"origin")) then
             ok = eval_next(t0(1),line,lp)
             ok = ok .and. eval_next(t0(2),line,lp)
             ok = ok .and. eval_next(t0(3),line,lp)
             if (.not.ok) then
                call ferror("struct_newcell","Wrong ORIGIN syntax in NEWCELL",faterr,line,syntax=.true.)
                return
             end if
          elseif (equal(word,"inv").or.equal(word,"inverse")) then
             doinv = .true.
          elseif (len_trim(word) > 0) then
             call ferror('struct_newcell','Unknown extra keyword',faterr,line,syntax=.true.)
             return
          else
             exit
          end if
       end do
       if (doinv) call matinv(x0,3)

       ! transform to the new crystal
       call s%c%newcell(x0,t0)
       changed = .true.
    end if

    if (changed) then
       write (uout,'("  Lattice vectors of the new cell in the old setting (cryst. coord.):")')
       write (uout,'(4X,3(A,X))') (string(x0(i,1),'f',12,7,4),i=1,3)
       write (uout,'(4X,3(A,X))') (string(x0(i,2),'f',12,7,4),i=1,3)
       write (uout,'(4X,3(A,X))') (string(x0(i,3),'f',12,7,4),i=1,3)
       write (uout,'("  Origin translation: ",3(A,X))') (string(t0(i),'f',12,7,4),i=1,3)
       if (dotyp == 1 .and. dorefine) &
          write (uout,'("  Atomic positions have been refined.")')
       write (uout,*)

       ! reset all fields and properties to the default
       call s%reset_fields()

       ! report
       if (verbose) &
          call s%report(.true.,.true.,.true.,.true.,.true.,.true.,.false.)
    else
       write (uout,'("+ Cell transformation leads to the same cell: skipping."/)')
    end if

  end subroutine struct_newcell

  !> Try to determine the molecular cell from the crystal geometry
  module subroutine struct_molcell(s,line)
    use systemmod, only: system
    use global, only: rborder_def, eval_next, dunit0, iunit
    use tools_io, only: ferror, faterr, uout, string

    type(system), intent(inout) :: s
    character*(*), intent(in) :: line

    integer :: i, j, lp
    real*8 :: xmin(3), xmax(3), rborder, raux
    logical :: ok

    if (.not.s%c%ismolecule) then
       call ferror('struct_molcell','MOLCELL works with MOLECULE, not CRYSTAL.',faterr,syntax=.true.)
       return
    end if
    if (any(abs(s%c%bb-90d0) > 1d-5)) then
       call ferror('struct_molcell','MOLCELL only allowed for orthogonal cells.',faterr,syntax=.true.)
       return
    end if

    ! defaults
    rborder = rborder_def

    ! read optional border input
    lp = 1
    ok = eval_next(raux,line,lp)
    if (ok) rborder = raux / dunit0(iunit)

    ! find the encompassing cube
    xmin = 1d40
    xmax = -1d30
    do i = 1, s%c%ncel
       do j = 1, 3
          xmin(j) = min(xmin(j),s%c%at(i)%x(j))
          xmax(j) = max(xmax(j),s%c%at(i)%x(j))
       end do
    end do

    ! apply the border
    do j = 1, 3
       xmin(j) = max(xmin(j) - rborder / s%c%aa(j),0d0)
       xmax(j) = min(xmax(j) + rborder / s%c%aa(j),1d0)
       s%c%molborder(j) = min(xmin(j),1d0-xmax(j))
    end do

    ! some output
    write (uout,'("* MOLCELL: set up a molecular cell")')
    write (uout,'("+ Limit of the molecule within the cell (cryst coords):")')
    write (uout,'("  a axis: ",A," -> ",A)') trim(string(s%c%molborder(1),'f',10,4)), trim(string(1d0-s%c%molborder(1),'f',10,4))
    write (uout,'("  b axis: ",A," -> ",A)') trim(string(s%c%molborder(2),'f',10,4)), trim(string(1d0-s%c%molborder(2),'f',10,4))
    write (uout,'("  c axis: ",A," -> ",A)') trim(string(s%c%molborder(3),'f',10,4)), trim(string(1d0-s%c%molborder(3),'f',10,4))

  end subroutine struct_molcell

  !> Calculate the Effective Coordination Number (ECON).
  module subroutine struct_econ(s)
    use systemmod, only: system
    use crystalmod, only: crystal
    use environmod, only: environ
    use global, only: iunitname0, dunit0, iunit
    use tools_io, only: uout, string, ioj_left, ioj_right
    use param, only: icrd_crys, bohrtoa
    type(system), intent(in) :: s

    logical :: ok
    integer :: i, j, k, n
    integer :: nat, ierr
    integer, allocatable :: eid(:)
    real*8 :: dist0, econ, up2d
    real*8 :: wi, numer, econprev
    real*8, allocatable :: econij(:,:), ndij(:,:), dist(:)
    real*8, allocatable :: econij_noit(:,:), ndij_noit(:,:), mindist(:)
    character(len=:), allocatable :: str, namestr

    real*8, parameter :: up2dmax = 15d0 / bohrtoa
    real*8, parameter :: wthresh = 1d-10
    real*8, parameter :: epsfac = (1d0 + 14d0 * log(10d0))**(1d0/6d0)

    allocate(econij(0:s%c%nspc,s%c%nneq),econij_noit(0:s%c%nspc,s%c%nneq))
    allocate(ndij(0:s%c%nspc,s%c%nneq),ndij_noit(0:s%c%nspc,s%c%nneq),mindist(0:s%c%nspc))
    econij = 0d0
    econij_noit = 0d0
    ndij = 0d0
    ndij_noit = 0d0

    ! initialize
    up2d = up2dmax

    main: do while(.true.)
       ! loop over non-equivalent atoms
       do i = 1, s%c%nneq
          ! skip if this is a single atom in a box
          if (s%c%ismolecule .AND. s%c%ncel == 1) cycle

          ! grab the environment for this atom
          call s%c%env%list_near_atoms(s%c%at(i)%x,icrd_crys,.true.,nat,ierr,eid,dist,up2d=up2d,nozero=.true.)

          ! get the minimum distance for all the species
          mindist = -1d0
          mindist(0) = dist(1)
          do k = 1, nat
             if (mindist(s%c%env%at(eid(k))%is) < 0d0) mindist(s%c%env%at(eid(k))%is) = dist(k)
             if (all(mindist >= 0d0)) exit
          end do

          ! loop over species
          do j = 0, s%c%nspc
             econprev = -1d0
             econ = 0d0
             dist0 = mindist(j)
             n = 0
             do while (abs(econ-econprev) > wthresh .or. n <= 2)
                n = n + 1
                econprev = econ

                ! loop over the environment atoms and consider only species j
                numer = 0d0
                econ = 0d0
                do k = 1, nat
                   if (j /= 0 .and. s%c%env%at(eid(k))%is /= j) cycle
                   wi = exp(1 - (dist(k)/dist0)**6)
                   numer = numer + dist(k) * wi
                   econ = econ + wi
                end do
                ok = (econ > 0d0)
                if (ok) dist0 = numer / econ

                ! if dist0 is dangerously close to the up2d, increase by a factor and try again
                if (.not.ok .or. dist0 > up2d / epsfac) then
                   up2d = 1.5d0 * up2d
                   cycle main
                end if

                ! save the non-iterative econ and average bond length values
                if (n == 1) then
                   ndij_noit(j,i) = dist0
                elseif (n == 2) then
                   econij_noit(j,i) = econ
                end if
             end do ! while (abs(econ-econprev) > wthresh)
             econij(j,i) = econ
             ndij(j,i) = dist0
          end do ! j = 0, s%c%nspc
       end do ! i = 1, s%c%nneq
       exit
    end do main

    ! write the output
    write (uout, '("* ECON")')
    write (uout, '("+ Effective Coordination Number (ECoN), per-species")')
    write (uout, '("# Please cite:")')
    write (uout, '("#   Nespolo, Acta Cryst. B, 72 (2016) 51. (doi.org/10.1107/S2052520615019472)")')
    write (uout, '("#   Hoppe, Z. Kristallogr. 150 (1979) 23. (doi.org/10.1524/zkri.1979.150.14.23)")')
    write (uout, '("# nid = non-equivalent atom ID. name = atomic name (symbol)")')
    write (uout, '("# spc = atomic species (* means all species)")')
    write (uout, '("# econ = effective coordination number species spc around non-equivalent")')
    write (uout, '("#        atom nid (iterative variant)")')
    write (uout, '("# 1econ = effective coordination number species spc around non-equivalent")')
    write (uout, '("#         atom nid (non-iterative variant using the shortest bond length))")')
    write (uout, '("# nd = mean weighted distance (",A,"), Eq. 3 in Nespolo, iterative variant. ")') iunitname0(iunit)
    write (uout, '("# 1nd = mean weighted distance (",A,"), non-iterative variant. ")') iunitname0(iunit)
    write (uout, '("# nid->spc   name(nid)->name(spc)     econ      1econ       nd         1nd")')
    do i = 1, s%c%nneq
       do j = 0, s%c%nspc
          if (j == 0) then
             str = "*   "
             namestr = "*      "
          else
             str = string(j,length=4,justify=ioj_left)
             namestr = string(s%c%spc(j)%name,length=7,justify=ioj_left)
          end if

          write (uout,'(A," -> ",A,A," -> ",99(A,X))') string(i,length=4,justify=ioj_right), str,&
             string(s%c%spc(s%c%at(i)%is)%name,length=9,justify=ioj_right), namestr,&
             string(econij(j,i),'f',length=10,decimal=4,justify=ioj_right),&
             string(econij_noit(j,i),'f',length=10,decimal=4,justify=ioj_right),&
             string(ndij(j,i)*dunit0(iunit),'f',length=10,decimal=4,justify=ioj_right),&
             string(ndij_noit(j,i)*dunit0(iunit),'f',length=10,decimal=4,justify=ioj_right)
       end do
    end do
    write (uout,*)

    deallocate(econij,ndij,econij_noit,ndij_noit,mindist)

  end subroutine struct_econ

  !> Identify atoms by their coordinates
  module subroutine struct_identify(s,line0,lp)
    use systemmod, only: system
    use global, only: iunit, iunit_bohr, iunit_ang, iunitname0, dunit0, &
       eval_next
    use tools_io, only: lgetword, getword, getline, equal, ferror, &
       faterr, uin, ucopy, uout, string, ioj_left, ioj_center, fopen_read
    use param, only: bohrtoa
    use types, only: realloc
    type(system), intent(in) :: s
    character*(*), intent(in) :: line0
    integer, intent(inout) :: lp

    logical :: ok
    character(len=:), allocatable :: line, word
    real*8 :: x0(3), xmin(3), xmax(3), x0out(3)
    real*8, allocatable :: pointlist(:,:)
    integer :: i, j, n, idx
    logical :: found, doenv

    integer :: ldunit, unit, mm
    integer, parameter :: unit_au = 1
    integer, parameter :: unit_ang = 2
    integer, parameter :: unit_x = 3

    real*8, parameter :: eps = 1d-4

    ! default units
    if (s%c%ismolecule) then
       if (iunit == iunit_bohr) then
          ldunit = unit_au
       elseif (iunit == iunit_ang) then
          ldunit = unit_ang
       end if
    else
       ldunit = unit_x
    endif

    ! parse the first word
    doenv = .true.
    word = lgetword(line0,lp)
    if (equal(word,'angstrom') .or.equal(word,'ang')) then
       ldunit = unit_ang
    elseif (equal(word,'bohr') .or.equal(word,'au')) then
       ldunit = unit_au
    elseif (equal(word,'cryst')) then
       ldunit = unit_x
    elseif (len_trim(word) > 0) then
       doenv = .false.
    endif

    ! read the input coordinates
    allocate(pointlist(3,10))
    n = 0
    if (doenv) then
       word = lgetword(line0,lp)
       if (len_trim(word) > 0) then
          call ferror('struct_identify','Unkwnon extra keyword',faterr,line0,syntax=.true.)
          return
       end if

       lp = 1
       ok = getline(uin,line,ucopy=ucopy)
       if (ok) then
          word = lgetword(line,lp)
       else
          word = ""
          lp = 1
       end if
       do while (ok.and..not.equal(word,'endidentify').and..not.equal(word,'end'))
          lp = 1
          ok = eval_next (x0(1), line, lp)
          ok = ok .and. eval_next (x0(2), line, lp)
          ok = ok .and. eval_next (x0(3), line, lp)
          if (ok) then
             ! this is a point, parse the last word
             word = lgetword(line,lp)
             if (equal(word,'angstrom') .or.equal(word,'ang')) then
                unit = unit_ang
             elseif (equal(word,'bohr') .or.equal(word,'au')) then
                unit = unit_au
             elseif (equal(word,'cryst')) then
                unit = unit_x
             else
                unit = ldunit
             endif

             if (unit == unit_ang) then
                x0 = s%c%c2x(x0 / bohrtoa - s%c%molx0)
             elseif (unit == unit_au) then
                x0 = s%c%c2x(x0 - s%c%molx0)
             endif
             n = n + 1
             if (n > size(pointlist,2)) then
                call realloc(pointlist,3,2*n)
             end if
             pointlist(:,n) = x0
          else
             ! this is an xyz file
             call readxyz()
          endif

          ! read next line
          lp = 1
          ok = getline(uin,line,ucopy=ucopy)
          if (ok) then
             word = lgetword(line,lp)
          else
             line = ""
             lp = 1
          end if
       enddo
       word = lgetword(line,lp)
       if (len_trim(word) > 0) then
          call ferror('struct_identify','Unkwnon extra keyword',faterr,line,syntax=.true.)
          return
       end if
    else
       call readxyz()
    endif

    xmin = 1d40
    xmax = -1d40
    found = .false.
    ! identify the atoms
    write(uout,'("* IDENTIFY: match input coordinates to atoms or CPs in the structure")')
    if (.not.s%c%ismolecule) then
       write(uout,'("# (x,y,z) is the position in crystallographic coordinates ")')
    else
       write(uout,'("# (x,y,z) is the position in Cartesian coordinates (",A,")")') &
          iunitname0(iunit)
    end if
    write(uout,'("# id        x             y             z     mult name  ncp  cp")')

    do i = 1, n
       x0 = pointlist(:,i)
       x0out = x0
       if (s%c%ismolecule) x0out = (s%c%x2c(x0)+s%c%molx0) * dunit0(iunit)
       idx = s%f(s%iref)%identify_cp(x0,eps)
       mm = s%c%get_mult(x0)
       if (idx > 0) then
          write (uout,'(99(A,X))') string(i,length=4,justify=ioj_left), &
             (string(x0out(j),'f',length=13,decimal=8,justify=4),j=1,3), &
             string(mm,length=3,justify=ioj_center), &
             string(s%f(s%iref)%cpcel(idx)%name,length=5,justify=ioj_center), &
             string(s%f(s%iref)%cpcel(idx)%idx,length=4,justify=ioj_center), &
             string(idx,length=4,justify=ioj_center)
          do j = 1, 3
             xmin(j) = min(xmin(j),x0(j))
             xmax(j) = max(xmax(j),x0(j))
             found = .true.
          end do
       else
          write (uout,'(99(A,X))') string(i,length=4,justify=ioj_left), &
             (string(x0out(j),'f',length=13,decimal=8,justify=4),j=1,3), &
             string(mm,length=3,justify=ioj_center), &
             string(" --- not found --- ")
       endif
    end do
    deallocate(pointlist)

    if (found) then
       if (.not.s%c%ismolecule) then
          write(uout,'("#")')
          write(uout,'("+ Cube, x0 (cryst): ",3(A,X))') (string(xmin(j),'f',decimal=8),j=1,3)
          write(uout,'("+ Cube, x1 (cryst): ",3(A,X))') (string(xmax(j),'f',decimal=8),j=1,3)
          xmin = s%c%c2x(s%c%x2c(xmin) - 2)
          xmax = s%c%c2x(s%c%x2c(xmax) + 2)
          write(uout,'("+ Cube + 2 bohr, x0 (cryst): ",3(A,X))') (string(xmin(j),'f',decimal=8),j=1,3)
          write(uout,'("+ Cube + 2 bohr, x1 (cryst): ",3(A,X))') (string(xmax(j),'f',decimal=8),j=1,3)
          xmin = s%c%c2x(s%c%x2c(xmin) - 3)
          xmax = s%c%c2x(s%c%x2c(xmax) + 3)
          write(uout,'("+ Cube + 5 bohr, x0 (cryst): ",3(A,X))') (string(xmin(j),'f',decimal=8),j=1,3)
          write(uout,'("+ Cube + 5 bohr, x1 (cryst): ",3(A,X))') (string(xmax(j),'f',decimal=8),j=1,3)
       else
          xmin = s%c%x2c(xmin)+s%c%molx0
          xmax = s%c%x2c(xmax)+s%c%molx0
          write(uout,'("+ Cube, x0 (",A,"): ",3(A,X))') iunitname0(iunit), (string(xmin(j)*dunit0(iunit),'f',decimal=8),j=1,3)
          write(uout,'("+ Cube, x1 (",A,"): ",3(A,X))') iunitname0(iunit), (string(xmax(j)*dunit0(iunit),'f',decimal=8),j=1,3)
       end if
    end if
    write(uout,*)

  contains
    !> Read an xyz file and add the coordinates to pointlist
    subroutine readxyz()
      use types, only: realloc
      use tools_io, only: fclose

      integer :: lu, nat, i
      real*8 :: x0(3)

      lu = fopen_read(word)
      read(lu,*) nat
      read(lu,*)
      do i = 1, nat
         read(lu,*) word, x0
         x0 = s%c%c2x(x0 / bohrtoa - s%c%molx0)
         n = n + 1
         if (n > size(pointlist,2)) then
            call realloc(pointlist,3,2*n)
         end if
         pointlist(:,n) = x0
      end do
      call fclose(lu)
    end subroutine readxyz

  end subroutine struct_identify

  !> Write a .mols file for neighcrys. Works even if Z' > 1 or if
  !> there are more than two molecules.
  module subroutine struct_makemols_neighcrys(line0,lp)
    use systemmod, only: system
    use tools_math, only: det3, cross
    use tools_io, only: getword, ferror, faterr, string, getline_raw, fopen_read, fclose, &
       fopen_write
    use types, only: realloc
    character*(*), intent(in) :: line0
    integer, intent(inout) :: lp

    character(len=:), allocatable :: errmsg
    character(len=:), allocatable :: file, line, line2
    logical :: laux, ok
    integer :: lu, i, j
    integer :: ncel, nmol, nmol2, idum, idax(3)
    integer, allocatable :: imap(:), idmol(:), iz(:)
    real*8, allocatable :: xx(:,:)
    real*8 :: rmat(3,3), xv(3), xnn
    character*10 :: cdum
    character*15, allocatable :: atlbl(:)

    real*8, parameter :: eps = 1d-6

    ! read the molecules in from the fort.21 file
    file = getword(line0,lp)
    inquire(file=file,exist=laux)
    if (.not.laux) &
       call ferror("makemols_neighcrys","file not found: " // string(file),faterr)

    ncel = 0
    nmol = 0
    lu = fopen_read(file)
    main: do while (getline_raw(lu,line))
       if (trim(line) == " Equivalent basis atoms") then
          ! default error message
          errmsg = "Unexpected error or end of line reading Equivalent basis atoms block"

          ! skip four lines
          ok = getline_raw(lu,line)
          ok = ok.and.getline_raw(lu,line)
          ok = ok.and.getline_raw(lu,line)
          ok = ok.and.getline_raw(lu,line)
          if (.not.ok) goto 999

          ! allocate space for the atomic information
          allocate(imap(10),idmol(10),iz(10),atlbl(10))

          ! read the atomic information and check against the loaded structure
          do while (.true.)
             ok = getline_raw(lu,line)
             if (.not.ok) goto 999
             if (len_trim(line) == 0) exit

             ncel = ncel + 1
             if (ncel > size(imap,1)) then
                call realloc(imap,2*ncel)
                call realloc(idmol,2*ncel)
                call realloc(iz,2*ncel)
                call realloc(atlbl,2*ncel)
             end if
             read(line,*,err=999) idum, iz(ncel), atlbl(ncel), cdum, idmol(ncel)
          end do
          if (ncel == 0) &
             call ferror("makemols_neighcrys","no atoms found in the fort.21 file",faterr)

          ! keep reading until we find the "crystallographic" keyword
          do while (.true.)
             ok = getline_raw(lu,line)
             if (.not.ok) goto 999
             if (index(line,"crystallographic") > 0) exit
          end do

          ! reallocate and allocate coordinates
          call realloc(imap,ncel)
          call realloc(idmol,ncel)
          call realloc(iz,ncel)
          call realloc(atlbl,ncel)
          allocate(xx(3,ncel))

          ! read the coordinates
          errmsg = "Unexpected error or end of line reading the coordinates block"
          ncel = 0
          do while (.true.)
             ok = getline_raw(lu,line)
             if (.not.ok) goto 999
             if (len_trim(line) == 0) exit
             ok = ok .and. getline_raw(lu,line2)
             if (.not.ok) goto 999

             ncel = ncel + 1
             if (ncel > size(imap,1)) then
                errmsg = "Too many atoms in coordinates block"
                goto 999
             end if
             read(line,*,err=999) idum, cdum, xx(:,ncel)
          end do

          ! we are done with this file
          nmol = maxval(idmol)
          exit main
       end if
    end do main
    call fclose(lu)
    errmsg = ""
    if (ncel == 0) &
       call ferror("makemols_neighcrys","no atoms found in the fort.21 file",faterr)
    if (nmol == 0) &
       call ferror("makemols_neighcrys","no molecules found in the fort.21 file",faterr)

    ! read the mols file
    file = getword(line0,lp)
    if (len_trim(file) == 0) then
       errmsg = "A name for the mols file is required"
       goto 999
    end if

    ! count the actual number of molecules
    nmol2 = 0
    do i = 1, nmol
       if (any(idmol(1:ncel) == i)) nmol2 = nmol2 + 1
    end do
    if (nmol2 == 0) &
       call ferror("makemols_neighcrys","no inequivalent molecules found in the fort.21 file",faterr)

    ! write the mols file
    lu = fopen_write(file)
    write (lu,'("MOLX ",A)') string(nmol2)
    do i = 1, nmol
       if (all(idmol(1:ncel) /= i)) cycle
       idax = 0
       do j = 1, ncel
          if (idmol(j) /= i) cycle

          if (idax(1) == 0) then
             idax(1) = j
             rmat(:,1) = xx(:,j)
          elseif (idax(2) == 0) then
             xnn = norm2(xx(:,j) - xx(:,idax(1)))
             if (xnn < eps) cycle
             idax(2) = j
             rmat(:,2) = (xx(:,j) - xx(:,idax(1))) / xnn
          else
             xnn = norm2(xx(:,j) - xx(:,idax(1)))
             if (xnn < eps) cycle
             rmat(:,3) = (xx(:,j) - xx(:,idax(1))) / xnn
             xv = cross(rmat(:,2),rmat(:,3))
             if (norm2(xv) >= eps) then
                idax(3) = j
                exit
             end if
          end if
       end do

       if (any(idax == 0)) then
          ! ! the molecule must be linear
          ! ! find any third atom in the system that is not collinear
          ! do j = 1, ncel
          !    if (idmol(j) == i) cycle
          !    xnn = norm2(xx(:,j) - xx(:,idax(1)))
          !    if (xnn < eps) cycle
          !    rmat(:,3) = (xx(:,j) - xx(:,idax(1))) / xnn
          !    xv = cross(rmat(:,2),rmat(:,3))
          !    if (norm2(xv) >= eps) then
          !       idax(3) = j
          !       exit
          !    end if
          ! end do
          call ferror("makemols_neighcrys","cannot be applied to a linear molecule",faterr)
       end if

       write (lu,'("X LINE  ",A,X,A," 1")') trim(atlbl(idax(1))), trim(atlbl(idax(2)))
       write (lu,'("Y PLANE ",A,X,A," 1",X,A," 1")') &
          trim(atlbl(idax(1))), trim(atlbl(idax(2))), trim(atlbl(idax(3)))
    end do
    write (lu,'("ENDS")')
    call fclose(lu)

    return
999 continue

    call ferror('struct_makemols_neighcrys',errmsg,faterr,line,syntax=.true.)
    return

  end subroutine struct_makemols_neighcrys

  !> Put the atoms of one molecule in the same order as another.
  module subroutine struct_molreorder(line,lp)
    use global, only: doguess
    use crystalmod, only: crystal
    use crystalseedmod, only: crystalseed
    use tools, only: qcksort
    use tools_math, only: crosscorr_triangle, rmsd_walker
    use tools_io, only: getword, string, ferror, faterr, lower, equal, isreal, uout, string
    use types, only: realloc
    use param, only: maxzat0
    character*(*), intent(in) :: line
    integer, intent(inout) :: lp

    type(crystal) :: cref, cx
    type(crystal), allocatable :: c(:)
    type(crystalseed) :: seed
    character*1024 :: fname(2)
    character(len=:), allocatable :: word, lword, wfile, msg
    integer :: i, j, n, is, ns, lp, nat
    real*8, allocatable :: t(:), iha(:,:), ihat(:,:,:)
    real*8, allocatable :: ihaux(:), ihataux(:,:), ihref(:), ihatref(:,:), ihatrefsave(:,:)
    real*8 :: xdiff, h, eps, rms1, rms2
    integer, allocatable :: nidold(:), idmult(:,:), nid(:), isuse(:), isperm(:,:)
    integer, allocatable :: cidxorig(:,:)
    real*8, allocatable :: intpeak(:), x1(:,:), x2(:,:), rmsd(:)
    logical, allocatable :: isinv(:)
    logical :: ok
    integer :: doguess_save
    real*8 :: rend
    integer :: npts

    integer, parameter :: isuse_valid = 0
    integer, parameter :: isuse_different_nat = 1
    integer, parameter :: isuse_different_rdf = 2
    integer, parameter :: isuse_could_not_assign = 3

    real*8, parameter :: sigma0 = 0.05d0
    integer, parameter :: npts0 = 1001
    real*8, parameter :: eps_default = 1d-4

    write(uout,'("* ORDER_MOLECULES: reorder the atoms in a molecule or a molecular crystal")')

    ! read the input
    ns = 0
    eps = eps_default
    wfile = ""
    do while(.true.)
       word = getword(line,lp)
       lword = lower(word)
       if (equal(lword,'write')) then
          wfile = getword(line,lp)
       elseif (equal(lword,'eps')) then
          ok = isreal(eps,line,lp)
          if (.not.ok) &
             call ferror("struct_order_molecules","error reading eps",faterr)
       elseif (len_trim(word) == 0) then
          exit
       else
          ns = ns + 1
          if (ns > 2) &
             call ferror("struct_order_molecules","cannot order more than two structures",faterr)
          fname(ns) = word
       end if
    end do
    if (ns /= 2) &
       call ferror("struct_order_molecules","need two structures to order",faterr)

    ! get the reference structure and check it is a molecule
    call struct_crystal_input(fname(1),-1,.false.,.false.,cr0=cref)
    if (.not.cref%isinit) &
       call ferror("struct_order_molecules","could not load structure" // string(fname(1)),faterr)
    if (.not.cref%ismolecule) &
       call ferror("struct_order_molecules","the first structure is not a molecule",faterr)
    if (cref%nmol > 1) &
       call ferror("struct_order_molecules","the first structure contains more than one molecule",faterr)

    ! get the other structure (do not guess the symmetry)
    call struct_crystal_input(fname(2),-1,.false.,.false.,cr0=cx)
    if (.not.cx%isinit) &
       call ferror("struct_order_molecules","could not load structure" // string(fname(2)),faterr)
    if (.not.cx%ismolecule) then
       if (.not.cx%ismol3d) &
          call ferror("struct_order_molecules","the target structure is not a molecular crystal",faterr)
       call cx%wholemols()
       if (any(cx%idxmol(1:cx%nmol) < 0)) &
          call ferror("struct_order_molecules","the target structure must have whole molecules",faterr)
    end if

    ! read the fragments from cx into structures
    ns = cx%nmol
    allocate(c(ns))
    rend = 0d0
    do i = 1, ns
       call seed%from_fragment(cx%mol(i),.true.)
       seed%border = 0d0
       call c(i)%struct_new(seed,.true.)
       rend = max(rend,maxval(c(i)%aa))
    end do
    npts = max(min(nint(rend * 21),npts0),10)

    ! allocate the use and permutation arrays
    allocate(isuse(ns),isperm(cref%nneq,ns))
    isuse = isuse_valid

    ! check that the number of atoms are equal
    do i = 1, ns
       if (cref%nneq /= c(i)%nneq) isuse(i) = isuse_different_nat
    end do
    nat = cref%nneq

    ! make the mapping between structure+atom and the original cidx
    ! sort because the from_fragment routine also sorts
    allocate(cidxorig(nat,ns))
    do is = 1, ns
       do i = 1, nat
          cidxorig(i,is) = cx%mol(is)%at(i)%cidx
       end do
       call qcksort(cidxorig(:,is))
    end do

    ! allocate space for the RDFs
    allocate(iha(npts,ns),ihat(npts,nat,ns),ihatrefsave(npts,nat))
    iha = 0d0
    ihat = 0d0

    ! get the RDF for the reference structure and save it
    h = rend / real(npts-1,8)
    call cref%rdf(0d0,rend,sigma0,.false.,npts,t,ihref,ihat=ihatref)
    ihref = ihref / sqrt(abs(crosscorr_triangle(h,ihref,ihref,1d0)))
    do j = 1, nat
       ihatref(:,j) = ihatref(:,j) / sqrt(abs(crosscorr_triangle(h,ihatref(:,j),ihatref(:,j),1d0)))
    end do
    ihatrefsave = ihatref

    ! check the total RDF of each fragment matches the reference
    do i = 1, ns
       if (isuse(i) /= isuse_valid) cycle

       ! calculate the RDFs
       call c(i)%rdf(0d0,rend,sigma0,.false.,npts,t,ihaux,ihat=ihataux)
       iha(:,i) = ihaux / sqrt(abs(crosscorr_triangle(h,ihaux,ihaux,1d0)))
       do j = 1, nat
          ihat(:,j,i) = ihataux(:,j) / sqrt(abs(crosscorr_triangle(h,ihataux(:,j),ihataux(:,j),1d0)))
       end do

       ! check that the molecules are identical
       xdiff = max(1d0 - crosscorr_triangle(h,ihref,iha(:,i),1d0),0d0)
       if (xdiff > eps) isuse(i) = isuse_different_rdf
    end do

    ! identify equivalent atoms
    allocate(idmult(2,nat),nid(nat),nidold(nat),intpeak(nat))
    main: do is = 1, ns
       if (isuse(is) /= isuse_valid) cycle

       intpeak = 0
       nidold = -1
       nid = 0
       ihatref = ihatrefsave
       do while (.true.)
          nidold = nid
          nid = 0

          ! recalculate the differences
          idmult = 0
          do i = 1, nat
             do j = 1, nat
                if (cref%spc(cref%at(i)%is)%z /= c(is)%spc(c(is)%at(j)%is)%z) cycle

                xdiff = max(1d0 - crosscorr_triangle(h,ihatref(:,i),ihat(:,j,is),1d0),0d0)
                if (xdiff < eps) then
                   nid(i) = nid(i) + 1
                   if (nid(i) > size(idmult,1)) &
                      call realloc(idmult,2*nid(i),nat)
                   idmult(nid(i),i) = j
                end if
             end do
          end do

          if (all(nid == 1)) then
             ! all done
             exit
          elseif (any(nid == 0)) then
             ! some atoms could not be assigned
             isuse(is) = isuse_could_not_assign
             cycle main
          elseif (all(nid == nidold)) then
             ! Did not change and all nids are positive and some are > 1. Must be because of symmetry
             ! so we arbitrarily assign a pair of atoms and continue
             do i = 1, nat
                if (nid(i) > 1) then
                   nid(i) = 1
                   exit
                end if
             end do
          end if

          ! re-do the reference structure and assign peak intensity to unique atoms
          do i = 1, nat
             if (nid(i) == 1) then
                intpeak(i) = maxzat0 + i
             else
                intpeak(i) = cref%spc(cref%at(i)%is)%z
             end if
          end do
          call cref%rdf(0d0,rend,sigma0,.false.,npts,t,ihaux,ihat=ihatref,intpeak=intpeak)
          do j = 1, nat
             ihatref(:,j) = ihatref(:,j) / sqrt(abs(crosscorr_triangle(h,ihatref(:,j),ihatref(:,j),1d0)))
          end do

          ! re-do the target structure and assign peak intensity to unique atoms
          do i = 1, nat
             intpeak(i) = c(is)%spc(c(is)%at(i)%is)%z
          end do
          do i = 1, nat
             if (nid(i) == 1) intpeak(idmult(1,i)) = maxzat0 + i
          end do
          call c(is)%rdf(0d0,rend,sigma0,.false.,npts,t,ihaux,ihat=ihataux,intpeak=intpeak)
          do j = 1, nat
             ihat(:,j,is) = ihataux(:,j) / sqrt(abs(crosscorr_triangle(h,ihataux(:,j),ihataux(:,j),1d0)))
          end do
       end do
       isperm(:,is) = idmult(1,:)
    end do main
    deallocate(iha,ihat,ihatrefsave,idmult,nid,nidold,intpeak)

    ! get the rmsd from walker
    allocate(rmsd(ns),x1(3,nat),x2(3,nat),isinv(ns))
    do i = 1, nat
       x1(:,i) = cref%at(i)%r
    end do
    rmsd = 0d0
    isinv = .false.
    do is = 1, ns
       if (isuse(is) /= isuse_valid) cycle
       do i = 1, nat
          x2(:,i) = c(is)%at(isperm(i,is))%r
       end do
       rms1 = rmsd_walker(x1,x2)
       x2 = -x2
       rms2 = rmsd_walker(x1,x2)
       if (rms1 <= rms2) then
          isinv(is) = .false.
          rmsd(is) = rms1
       else
          isinv(is) = .true.
          rmsd(is) = rms2
       end if
    end do
    deallocate(c,x1,x2)

    ! report on the results
    write (uout,'("+ Reference structure: ",A)') string(cref%file)
    write (uout,'("+ Target structure: ",A)') string(fname(2))
    if (cx%ismolecule) then
       write (uout,'("  The target structure is a molecule with ",A," fragments.")') string(ns)
    else
       write (uout,'("  The target structure is a molecular crystal with ",A," fragments.")') string(ns)
    end if
    write (uout,'("# List of reordered structures (",A,")")') string(ns)
    write (uout,'("#id -- Reorder result --")')
    do is = 1, ns
       if (isuse(is) == isuse_different_nat) then
          msg = "the target and reference structures have different number of atoms"
       elseif (isuse(is) == isuse_different_rdf) then
          msg = "the target and reference structures have different total RDFs"
       elseif (isuse(is) == isuse_could_not_assign) then
          msg = "could not assign some atoms in the target structure"
       else
          msg = ""
          do i = 1, nat
             msg = msg // " " // string(isperm(i,is))
          end do
       end if
       if (isuse(is) /= isuse_valid) then
          write (uout,'(X,A," skipped (",A,")")') string(is,2), string(msg)
       else
          write (uout,'(X,A," success (rmse=",A,",inv=",A,",perm=",A,")")') &
             string(is,2), trim(string(rmsd(is),'e',decimal=4)), string(isinv(is)), string(msg)
       end if
    end do
    write (uout,*)
    deallocate(rmsd,isinv)

    ! write the final structure
    if (len_trim(wfile) > 0 .and. all(isuse == isuse_valid)) then
       write (uout,'("* WRITE file: ",A/)') string(wfile)

       call cx%makeseed(seed,.false.)
       n = 0
       do is = 1, ns
          do i = 1, nat
             n = n + 1
             seed%x(:,n) = cx%atcel(cidxorig(isperm(i,is),is))%x
             seed%is(n) = cx%atcel(cidxorig(isperm(i,is),is))%is
          end do
       end do
       call cx%struct_new(seed,.true.)
       call cx%wholemols()
       call cx%write_simple_driver(wfile)
    end if
    deallocate(isperm,cidxorig,isuse)

  end subroutine struct_molreorder

end submodule proc
