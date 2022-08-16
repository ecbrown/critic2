! Copyright (c) 2019 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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

! Some utilities for building the GUI (e.g. wrappers around ImGui routines).
submodule (gui_window) proc
  use gui_interfaces_cimgui
  implicit none

  ! Count ID for keeping track of windows and widgets
  integer :: idcount = 0

  ! column ids for the table in the tree widget
  integer(c_int), parameter :: ic_id = 0
  integer(c_int), parameter :: ic_name = 1
  integer(c_int), parameter :: ic_spg = 2
  integer(c_int), parameter :: ic_v = 3
  integer(c_int), parameter :: ic_nneq = 4
  integer(c_int), parameter :: ic_ncel = 5
  integer(c_int), parameter :: ic_nmol = 6
  integer(c_int), parameter :: ic_a = 7
  integer(c_int), parameter :: ic_b = 8
  integer(c_int), parameter :: ic_c = 9
  integer(c_int), parameter :: ic_alpha = 10
  integer(c_int), parameter :: ic_beta = 11
  integer(c_int), parameter :: ic_gamma = 12

contains

  !> Initialize a window of the given type. If isiopen, initialize it
  !> as open.
  module subroutine window_init(w,type,isopen)
    class(window), intent(inout) :: w
    integer, intent(in) :: type
    logical, intent(in) :: isopen

    w%isinit = .true.
    w%isopen = isopen
    w%type = type
    w%id = -1

  end subroutine window_init

  !> Draw an ImGui window.
  module subroutine window_draw(w)
    use tools_io, only: string
    class(window), intent(inout), target :: w

    character(kind=c_char,len=:), allocatable, target :: str

    ! First pass: assign ID, name, and flags
    if (w%id < 0) then
       idcount = idcount + 1
       w%id = idcount
       if (w%type == wintype_tree) then
          ! w%name = "Tree###" // string(w%id) // c_null_char
          w%name = "Tree" // c_null_char
          w%flags = ImGuiWindowFlags_None
       elseif (w%type == wintype_view) then
          ! w%name = "View###" // string(w%id) // c_null_char
          w%name = "View" // c_null_char
          w%flags = ImGuiWindowFlags_None
       elseif (w%type == wintype_console) then
          ! w%name = "Console###" // string(w%id) // c_null_char
          w%name = "Console" // c_null_char
          w%flags = ImGuiWindowFlags_None
       end if
    end if

    if (w%isopen) then
       if (igBegin(c_loc(w%name),w%isopen,w%flags)) then
          ! assign the pointer ID
          w%ptr = igGetCurrentWindow()

          ! draw the window contents, depending on type
          if (w%type == wintype_tree) then
             call w%draw_tree()
          elseif (w%type == wintype_view) then
             str = "Hello View!"
             call igText(c_loc(str))
          elseif (w%type == wintype_console) then
             str = "Hello Console!"
             call igText(c_loc(str))
          end if
       end if
       call igEnd()
    end if

  end subroutine window_draw

  !> Draw the contents of a tree window
  module subroutine draw_tree(w)
    use gui_utils, only: igIsItemHovered_delayed
    use gui_main, only: sys, sysc, sys_empty, sys_init, tooltip_delay, TableCellBg_Mol,&
       TableCellBg_MolClus, TableCellBg_MolCrys, TableCellBg_Crys3d, TableCellBg_Crys2d,&
       TableCellBg_Crys1d

    use gui_keybindings, only: is_bind_event, BIND_TREE_MOVE_UP, BIND_TREE_MOVE_DOWN
    use tools_io, only: string
    use param, only: bohrtoa
    use c_interface_module
    class(window), intent(inout), target :: w

    character(kind=c_char,len=:), allocatable, target :: str
    type(ImVec2) :: zero2
    integer(c_int) :: flags, color
    integer :: i, j, nshown
    logical(c_bool) :: selected
    logical :: needsort
    type(c_ptr) :: ptrc
    logical, save :: ttshown = .false. ! delayed tooltips
    type(ImGuiTableSortSpecs), pointer :: sortspecs
    type(ImGuiTableColumnSortSpecs), pointer :: colspecs

    ! two zeros
    zero2%x = 0
    zero2%y = 0

    ! initialize table
    if (.not.allocated(w%iord)) then
       call w%update_tree()
       w%table_sortcid = 0
       w%table_sortdir = 1
       w%table_selected = 1
    end if
    nshown = size(w%iord,1)

    ! process keybindings
    if (igIsWindowFocused(ImGuiFocusedFlags_RootAndChildWindows)) then
       if (is_bind_event(BIND_TREE_MOVE_UP)) then
          w%table_selected = max(w%table_selected-1,1)
       elseif (is_bind_event(BIND_TREE_MOVE_DOWN)) then
          w%table_selected = min(w%table_selected+1,nshown)
       end if
    end if

    ! set up the table
    str = "Structures" // c_null_char
    flags = ImGuiTableFlags_Borders
    flags = ior(flags,ImGuiTableFlags_Resizable)
    flags = ior(flags,ImGuiTableFlags_ScrollY)
    flags = ior(flags,ImGuiTableFlags_Reorderable)
    flags = ior(flags,ImGuiTableFlags_Hideable)
    flags = ior(flags,ImGuiTableFlags_Sortable)
    flags = ior(flags,ImGuiTableFlags_SizingFixedFit)
    if (igBeginTable(c_loc(str),13,flags,zero2,0._c_float)) then
       if (w%forceresize) then
          call igTableSetColumnWidthAutoAll(igGetCurrentTable())
          w%forceresize = .false.
       end if

       ! set up the columns
       ! ID - name - spg - volume - nneq - ncel - nmol - a - b - c - alpha - beta - gamma
       str = "ID" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultSort
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_id)

       str = "Name" // c_null_char
       flags = ImGuiTableColumnFlags_WidthStretch
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_name)

       str = "spg" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_spg)

       str = "V/Å³" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_v)

       str = "nneq" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_nneq)

       str = "ncel" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_ncel)

       str = "nmol" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_nmol)

       str = "a/Å" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_a)

       str = "b/Å" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_b)

       str = "c/Å" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_c)

       str = "α/°" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_alpha)

       str = "β/°" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_beta)

       str = "γ/°" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_gamma)
       call igTableSetupScrollFreeze(0, 1) ! top row always visible

       ! fetch the sort specs, sort the data if necessary
       needsort = .false.
       ptrc = igTableGetSortSpecs()
       if (c_associated(ptrc)) then
          call c_f_pointer(ptrc,sortspecs)
          call c_f_pointer(sortspecs%Specs,colspecs)
          w%table_sortcid = colspecs%ColumnUserID
          w%table_sortdir = colspecs%SortDirection
          if (sortspecs%SpecsDirty .and. nshown > 1) then
             needsort = .true.
             sortspecs%SpecsDirty = .false.
          end if
       end if
       if (needsort) then
          call w%sort_tree(w%table_sortcid,w%table_sortdir)
       end if

       ! draw the header
       call igTableHeadersRow()

       ! draw the rows
       do j = 1, nshown
          i = w%iord(j)
          if (sysc(i)%status == sys_empty) cycle
          call igTableNextRow(ImGuiTableRowFlags_None, 0._c_float);

          ! set background color for the name cell, if not selected
          if (w%table_selected /= j) then
             if (sysc(i)%seed%ismolecule) then
                color = igGetColorU32_Vec4(TableCellBg_Mol)
                if (sysc(i)%status == sys_init) then
                   if (sys(i)%c%nmol > 1) color = igGetColorU32_Vec4(TableCellBg_MolClus)
                endif
             else
                color = igGetColorU32_Vec4(TableCellBg_Crys3d)
                if (sysc(i)%status == sys_init) then
                   if (sys(i)%c%ismol3d .or. sys(i)%c%nlvac == 3) then
                      color = igGetColorU32_Vec4(TableCellBg_MolCrys)
                   elseif (sys(i)%c%nlvac == 2) then
                      color = igGetColorU32_Vec4(TableCellBg_Crys1d)
                   elseif (sys(i)%c%nlvac == 1) then
                      color = igGetColorU32_Vec4(TableCellBg_Crys2d)
                   end if
                end if
             end if
             call igTableSetBgColor(ImGuiTableBgTarget_CellBg, color, ic_name)
          end if

          ! ID
          if (igTableSetColumnIndex(ic_id)) then
             str = string(i) // c_null_char
             flags = ImGuiSelectableFlags_SpanAllColumns
             selected = (w%table_selected==j)
             if (igSelectable_Bool(c_loc(str),selected,flags,zero2)) then
                w%table_selected = j
             end if

             ! delayed tooltip with info about the system
             if (igIsItemHovered_delayed(ImGuiHoveredFlags_None,tooltip_delay,ttshown)) then
                str = tree_tooltip_string(i)
                call igSetTooltip(c_loc(str))
             end if
          end if

          ! name
          if (igTableSetColumnIndex(ic_name)) then
             str = trim(sysc(i)%seed%name) // c_null_char
             if (sysc(i)%status == sys_init) then
                call igText(c_loc(str))
             else
                call igTextDisabled(c_loc(str))
             end if
          end if

          if (sysc(i)%status == sys_init) then
             if (igTableSetColumnIndex(ic_spg)) then ! spg
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                elseif (.not.sys(i)%c%spgavail) then
                   str = "n/a" // c_null_char
                else
                   str = trim(sys(i)%c%spg%international_symbol) // c_null_char
                end if
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_v)) then ! volume
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%omega*bohrtoa**3,'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_nneq)) then ! nneq
                str = string(sys(i)%c%nneq) // c_null_char
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_ncel)) then ! ncel
                str = string(sys(i)%c%ncel) // c_null_char
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_nmol)) then ! nmol
                str = string(sys(i)%c%nmol) // c_null_char
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_a)) then ! a
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%aa(1)*bohrtoa,'f',decimal=4) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_b)) then ! b
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%aa(2)*bohrtoa,'f',decimal=4) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_c)) then ! c
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%aa(3)*bohrtoa,'f',decimal=4) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_alpha)) then ! alpha
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%bb(1),'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_beta)) then ! beta
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%bb(2),'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_gamma)) then ! gamma
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%bb(3),'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if

          end if

       end do

       call igEndTable()
    end if

  end subroutine draw_tree

  ! Update the table rows by building a new row index array
  ! (iord). Only the systems that are not empty are pointed by
  ! iord. This is routine is used when the systems change.
  module subroutine update_tree(w)
    use gui_main, only: sysc, nsys, sys_empty
    class(window), intent(inout) :: w

    integer :: i, n

    if (allocated(w%iord)) deallocate(w%iord)
    n = count(sysc(1:nsys)%status /= sys_empty)
    allocate(w%iord(max(n,1)))
    w%iord(1) = 1
    if (n > 0) then
       n = 0
       do i = 1, nsys
          if (sysc(i)%status /= sys_empty) then
             n = n + 1
             w%iord(n) = i
          end if
       end do
    end if

  end subroutine update_tree

  ! Sort the table row order by column cid and in direction dir
  ! (ascending=1, descending=2). Modifies the w%iord.
  module subroutine sort_tree(w,cid,dir)
    use gui_main, only: sys, sysc, sys_init, sys_empty
    use tools, only: mergesort
    use tools_math, only: invert_permutation
    use tools_io, only: ferror, faterr
    use types, only: vstring
    class(window), intent(inout) :: w
    integer(c_int), intent(in) :: cid, dir

    integer :: i, n, nvalid, nnovalid
    integer, allocatable :: ival(:), iperm(:), ivalid(:), inovalid(:)
    logical, allocatable :: valid(:)
    real*8, allocatable :: rval(:)
    type(vstring), allocatable :: sval(:)
    logical :: doit

    ! initialize the identity permutation
    n = size(w%iord,1)
    allocate(iperm(n),valid(n))
    do i = 1, n
       iperm(i) = i
    end do
    valid = .true.

    ! different types, different sorts
    if (cid == ic_id .or. cid == ic_nneq .or. cid == ic_ncel .or. cid == ic_nmol) then
       ! sort by integer
       allocate(ival(n))
       do i = 1, n
          if (cid == ic_id) then
             ival(i) = w%iord(i)
          elseif (sysc(w%iord(i))%status == sys_init) then
             if (cid == ic_nneq) then
                ival(i) = sys(w%iord(i))%c%nneq
             elseif (cid == ic_ncel) then
                ival(i) = sys(w%iord(i))%c%ncel
             elseif (cid == ic_nmol) then
                ival(i) = sys(w%iord(i))%c%nmol
             end if
          else
             ival(i) = huge(1)
             valid(i) = .false.
          end if
       end do
       call mergesort(ival,iperm,1,n)
       deallocate(ival)
    elseif (cid == ic_v .or. cid == ic_a .or. cid == ic_b .or. cid == ic_c .or.&
       cid == ic_alpha .or. cid == ic_beta .or. cid == ic_gamma) then
       ! sort by real
       allocate(rval(n))
       do i = 1, n
          doit = sysc(w%iord(i))%status == sys_init
          if (doit) doit = (.not.sys(w%iord(i))%c%ismolecule)
          if (doit) then
             if (cid == ic_v) then
                rval(i) = sys(w%iord(i))%c%omega
             elseif (cid == ic_a) then
                rval(i) = sys(w%iord(i))%c%aa(1)
             elseif (cid == ic_b) then
                rval(i) = sys(w%iord(i))%c%aa(2)
             elseif (cid == ic_c) then
                rval(i) = sys(w%iord(i))%c%aa(3)
             elseif (cid == ic_alpha) then
                rval(i) = sys(w%iord(i))%c%bb(1)
             elseif (cid == ic_beta) then
                rval(i) = sys(w%iord(i))%c%bb(2)
             elseif (cid == ic_gamma) then
                rval(i) = sys(w%iord(i))%c%bb(3)
             end if
          else
             rval(i) = huge(1d0)
             valid(i) = .false.
          end if
       end do
       call mergesort(rval,iperm,1,n)
       deallocate(rval)
    elseif (cid == ic_name .or. cid == ic_spg) then
       ! sort by string
       allocate(sval(n))
       do i = 1, n
          if (cid == ic_name .and. sysc(w%iord(i))%status /= sys_empty) then
             sval(i)%s = trim(sysc(w%iord(i))%seed%name)
          else
             doit = (cid == ic_spg) .and. (sysc(w%iord(i))%status == sys_init)
             if (doit) doit = .not.sys(w%iord(i))%c%ismolecule
             if (doit) doit = sys(w%iord(i))%c%spgavail
             if (doit) then
                sval(i)%s = trim(sys(w%iord(i))%c%spg%international_symbol)
             else
                sval(i)%s = ""
                valid(i) = .false.
             end if
          end if
       end do
       call mergesort(sval,iperm,1,n)
       deallocate(sval)
    else
       call ferror('sort_tree','column sorting not implemented',faterr)
    end if
    valid = valid(iperm)

    ! reverse the permutation, if requested; put the no-valids at the end
    allocate(ivalid(count(valid)),inovalid(n-count(valid)))
    nvalid = 0
    nnovalid = 0
    do i = 1, n
       if (valid(i)) then
          nvalid = nvalid + 1
          ivalid(nvalid) = iperm(i)
       else
          nnovalid = nnovalid + 1
          inovalid(nnovalid) = iperm(i)
       end if
    end do
    do i = nvalid, 1, -1
       if (dir == 2) then
          iperm(nvalid-i+1) = ivalid(i)
       else
          iperm(i) = ivalid(i)
       end if
    end do
    do i = 1, nnovalid
       iperm(nvalid+i) = inovalid(i)
    end do
    deallocate(ivalid,inovalid)

    ! apply the permutation
    w%iord = w%iord(iperm)
    w%table_selected = findloc(iperm,w%table_selected,1)

  end subroutine sort_tree

  !xx! private procedures

  ! Return the string for the tooltip shown by the tree window,
  ! corresponding to system i.
  function tree_tooltip_string(i) result(str)
    use crystalmod, only: pointgroup_info, holo_string
    use gui_main, only: sys, sysc, nsys, sys_init
    use tools_io, only: string
    use param, only: bohrtoa, maxzat, atmass, pcamu, bohr2cm
    use tools_math, only: gcd
    integer, intent(in) :: i
    character(kind=c_char,len=:), allocatable, target :: str

    integer, allocatable :: nis(:)
    integer :: k, iz
    real*8 :: maxdv, mass, dens
    integer :: nelec
    character(len=3) :: schpg
    integer :: holo, laue
    integer :: izp0

    str = ""
    if (i < 1 .or. i > nsys) return

    ! file
    str = "||" // trim(sysc(i)%seed%name) // "||" // new_line(str)
    if (sysc(i)%status == sys_init) then
       ! file and system type
       str = str // trim(sysc(i)%seed%file) // new_line(str)
       if (sys(i)%c%ismolecule) then
          if (sys(i)%c%nmol == 1) then
             str = str // "A molecule." // new_line(str)
          else
             str = str // "A molecular cluster with " // string(sys(i)%c%nmol) // " fragments." //&
                new_line(str)
          end if
       elseif (sys(i)%c%ismol3d .or. sys(i)%c%nlvac == 3) then
          str = str // "A molecular crystal with Z=" // string(sys(i)%c%nmol)
          if (sys(i)%c%spgavail) then
             izp0 = 0
             do k = 1, sys(i)%c%nmol
                if (sys(i)%c%idxmol(k) < 0) then
                   izp0 = -1
                   exit
                elseif (sys(i)%c%idxmol(k) == 0) then
                   izp0 = izp0 + 1
                end if
             end do
             if (izp0 > 0) then
                str = str // " and Z'=" // string(izp0)
             else
                str = str // " and Z'<1"
             end if
          end if
          str = str // "." // new_line(str)
       elseif (sys(i)%c%nlvac == 2) then
          str = str // "A 1D periodic (polymer) structure." //&
             new_line(str)
       elseif (sys(i)%c%nlvac == 1) then
          str = str // "A 2D periodic (layered) structure." //&
             new_line(str)
       else
          str = str // "A periodic crystal." //&
             new_line(str)
       end if
       str = str // new_line(str)

       ! number of atoms, electrons, molar mass
       str = str // string(sys(i)%c%ncel) // " atoms, " //&
          string(sys(i)%c%nneq) // " non-eq atoms, "//&
          string(sys(i)%c%nspc) // " species," // new_line(str)
       nelec = 0
       mass = 0d0
       do k = 1, sys(i)%c%nneq
          iz = sys(i)%c%spc(sys(i)%c%at(k)%is)%z
          if (iz >= maxzat .or. iz <= 0) cycle
          nelec = nelec + iz * sys(i)%c%at(k)%mult
          mass = mass + atmass(iz) * sys(i)%c%at(k)%mult
       end do
       str = str // string(nelec) // " electrons, " //&
          string(mass,'f',decimal=3) // " amu per cell" // new_line(str)
       ! empirical formula
       allocate(nis(sys(i)%c%nspc))
       nis = 0
       do k = 1, sys(i)%c%nneq
          nis(sys(i)%c%at(k)%is) = nis(sys(i)%c%at(k)%is) + sys(i)%c%at(k)%mult
       end do
       maxdv = gcd(nis,sys(i)%c%nspc)
       str = str // "Formula: "
       do k = 1, sys(i)%c%nspc
          str = str // string(sys(i)%c%spc(k)%name) // string(nint(nis(k)/maxdv)) // " "
       end do
       str = str // new_line(str) // new_line(str)

       if (.not.sys(i)%c%ismolecule) then
          ! cell parameters, volume, density
          str = str // "a/b/c (Å): " // &
             string(sys(i)%c%aa(1)*bohrtoa,'f',decimal=4) // " " //&
             string(sys(i)%c%aa(2)*bohrtoa,'f',decimal=4) // " " //&
             string(sys(i)%c%aa(3)*bohrtoa,'f',decimal=4) //&
             new_line(str)
          str = str // "α/β/γ (°): " // &
             string(sys(i)%c%bb(1),'f',decimal=2) // " " //&
             string(sys(i)%c%bb(2),'f',decimal=2) // " " //&
             string(sys(i)%c%bb(3),'f',decimal=2) // " " //&
             new_line(str)
          str = str // "V (Å³): " // &
             string(sys(i)%c%omega*bohrtoa**3,'f',decimal=2) // new_line(str)
          dens = (mass*pcamu) / (sys(i)%c%omega*bohr2cm**3)
          str = str // "Density (g/cm³): " // string(dens,'f',decimal=3) // new_line(str) &
             // new_line(str)

          ! symmetry
          if (sys(i)%c%spgavail) then
             call pointgroup_info(sys(i)%c%spg%pointgroup_symbol,schpg,holo,laue)
             str = str // "Symmetry: " // &
                string(sys(i)%c%spg%international_symbol) // " (" //&
                string(sys(i)%c%spg%spacegroup_number) // "), " //&
                string(holo_string(holo)) // "," //&
                new_line(str)

             str = str // string(sys(i)%c%neqv) // " symm-ops, " //&
                string(sys(i)%c%ncv) // " cent-vecs" //&
                new_line(str)
          else
             str = str // "Symmetry info not available" // new_line(str)
          end if
          str = str // new_line(str)
       end if

       ! number of scalar fields
       str = str // string(sys(i)%nf) // " scalar fields loaded" // new_line(str)
    else
       ! not initialized
       str = str // "Not initialized" // new_line(str)
    end if
    str = str // c_null_char

  end function tree_tooltip_string

end submodule proc
