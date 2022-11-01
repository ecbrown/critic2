! Copyright (c) 2019-2022 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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

! Windows, view.
submodule (windows) view
  use interfaces_cimgui
  implicit none

  ! 4-identity matrix (c-float)
  real(c_float), parameter :: zero = 0._c_float
  real(c_float), parameter :: one = 1._c_float
  real(c_float), parameter :: eye4(4,4) = reshape((/&
     one,zero,zero,zero,&
     zero,one,zero,zero,&
     zero,zero,one,zero,&
     zero,zero,zero,one/),shape(eye4))

contains

  !xx! view

  !> Draw the view.
  module subroutine draw_view(w)
    use interfaces_opengl3
    use interfaces_cimgui
    use scenes, only: reptype_atoms
    use utils, only: iw_calcheight
    use gui_main, only: sysc, sys_init, nsys, g
    use utils, only: iw_text, iw_button, iw_tooltip
    use tools_io, only: string
    class(window), intent(inout), target :: w

    integer :: i, nrep, id
    type(ImVec2) :: szavail, sz0, sz1, szero
    type(ImVec4) :: tint_col, border_col
    character(kind=c_char,len=:), allocatable, target :: str1, str2, str3, str4
    logical(c_bool) :: is_selected
    logical :: hover
    integer(c_int) :: amax, flags
    real(c_float) :: scal, width

    logical, save :: ttshown = .false. ! tooltip flag

    ! coordinate this with representation_menu in scenes module
    integer(c_int), parameter :: ic_closebutton = 0
    integer(c_int), parameter :: ic_viewbutton = 1
    integer(c_int), parameter :: ic_name = 2
    integer(c_int), parameter :: ic_editbutton = 3

    ! initialize
    szero%x = 0
    szero%y = 0

    ! gear menu
    str1="##viewgear" // c_null_char
    if (iw_button("⚙")) then
       call igOpenPopup_Str(c_loc(str1),ImGuiPopupFlags_None)
    end if
    if (igBeginPopupContextItem(c_loc(str1),ImGuiPopupFlags_None)) then
       ! representations table
       str2 = "Representations##0,0" // c_null_char

       flags = ImGuiTableFlags_NoSavedSettings
       flags = ior(flags,ImGuiTableFlags_SizingFixedFit)
       flags = ior(flags,ImGuiTableFlags_NoBordersInBody)
       flags = ior(flags,ImGuiTableFlags_ScrollY)
       sz0%x = 0
       nrep = count(sysc(w%view_selected)%sc%rep(1:sysc(w%view_selected)%sc%nrep)%isinit)
       nrep = min(nrep,10)
       sz0%y = iw_calcheight(nrep,0,.true.)
       if (igBeginTable(c_loc(str2),4,flags,sz0,0._c_float)) then
          str3 = "[close button]##1closebutton" // c_null_char
          flags = ImGuiTableColumnFlags_None
          width = max(4._c_float, g%FontSize + 2._c_float)
          call igTableSetupColumn(c_loc(str3),flags,width,ic_closebutton)

          str3 = "[view button]##1viewbutton" // c_null_char
          flags = ImGuiTableColumnFlags_None
          width = max(4._c_float, g%FontSize + 2._c_float)
          call igTableSetupColumn(c_loc(str3),flags,width,ic_viewbutton)

          str3 = "[name]##1name" // c_null_char
          flags = ImGuiTableColumnFlags_WidthStretch
          call igTableSetupColumn(c_loc(str3),flags,0.0_c_float,ic_name)

          str3 = "[edit button]##1editbutton" // c_null_char
          flags = ImGuiTableColumnFlags_None
          width = max(4._c_float, g%FontSize + 2._c_float)
          call igTableSetupColumn(c_loc(str3),flags,width,ic_editbutton)

          if (w%view_selected > 0 .and. w%view_selected <= nsys) then
             if (sysc(w%view_selected)%sc%representation_menu(w%id)) &
                w%forcerender = .true.
          end if
          call igEndTable()
       end if

       ! new representation selectable
       str2 = "Add Representation" // c_null_char
       if (igBeginMenu(c_loc(str2),.true._c_bool)) then
          str3 = "Atoms" // c_null_char
          if (igMenuItem_Bool(c_loc(str3),c_null_ptr,.false._c_bool,.true._c_bool)) then
             id = sysc(w%view_selected)%sc%get_new_representation_id()
             call sysc(w%view_selected)%sc%rep(id)%init(w%view_selected,id,reptype_atoms)
             w%forcerender = .true.
          end if
          call iw_tooltip("Add a representation for the atoms",ttshown)

          call igEndMenu()
       end if
       call iw_tooltip("Add a representation to the view",ttshown)


       call igEndPopup()
    end if
    call iw_tooltip("Change the view options")

    ! the selected system combo
    call igSameLine(0._c_float,-1._c_float)
    str2 = "" // c_null_char
    if (w%view_selected >= 1 .and. w%view_selected <= nsys) then
       if (sysc(w%view_selected)%status == sys_init) &
          str2 = string(w%view_selected) // ": " // trim(sysc(w%view_selected)%seed%name) // c_null_char
    end if
    str1 = "##systemcombo" // c_null_char
    if (igBeginCombo(c_loc(str1),c_loc(str2),ImGuiComboFlags_None)) then
       do i = 1, nsys
          if (sysc(i)%status == sys_init) then
             is_selected = (w%view_selected == i)
             str2 = string(i) // ": " // trim(sysc(i)%seed%name) // c_null_char
             if (igSelectable_Bool(c_loc(str2),is_selected,ImGuiSelectableFlags_None,szero)) then
                if (w%view_selected /= i) w%forcerender = .true.
                w%view_selected = i
             end if
             if (is_selected) &
                call igSetItemDefaultFocus()
          end if
       end do
       call igEndCombo()
    end if
    call iw_tooltip("Choose the system displayed",ttshown)

    ! get the remaining size for the texture
    call igGetContentRegionAvail(szavail)

    ! resize the render texture if not large enough
    amax = max(ceiling(max(szavail%x,szavail%y)),1)
    if (amax > w%FBOside) then
       amax = max(ceiling(1.5 * ceiling(max(szavail%x,szavail%y))),1)
       call w%delete_texture_view()
       call w%create_texture_view(amax)
       w%forcerender = .true.
    end if

    ! render the image to the texture, if requested
    if (w%forcerender) then
       call glBindFramebuffer(GL_FRAMEBUFFER, w%FBO)
       call glViewport(0_c_int,0_c_int,w%FBOside,w%FBOside)
       call glClearColor(0.,0.,0.,0.)
       call glClear(ior(GL_COLOR_BUFFER_BIT,GL_DEPTH_BUFFER_BIT))

       if (w%view_selected > 0 .and. w%view_selected <= nsys) &
          call sysc(w%view_selected)%sc%render()

       call glBindFramebuffer(GL_FRAMEBUFFER, 0)
       w%forcerender = .false.
    end if

    ! draw the texture, largest region with the same shape as the available region
    ! that fits into the texture square
    scal = real(w%FBOside,c_float) / max(max(szavail%x,szavail%y),1._c_float)
    sz0%x = 0.5 * (real(w%FBOside,c_float) - szavail%x * scal) / real(w%FBOside,c_float)
    sz0%y = 0.5 * (real(w%FBOside,c_float) - szavail%y * scal) / real(w%FBOside,c_float)
    sz1%x = 1._c_float - sz0%x
    sz1%y = 1._c_float - sz0%y

    ! border and tint for the image, draw the image, update the rectangle
    tint_col%x = 1._c_float
    tint_col%y = 1._c_float
    tint_col%z = 1._c_float
    tint_col%w = 1._c_float
    border_col%x = 0._c_float
    border_col%y = 0._c_float
    border_col%z = 0._c_float
    border_col%w = 0._c_float
    call igImage(w%FBOtex, szavail, sz0, sz1, tint_col, border_col)
    hover = igIsItemHovered(ImGuiHoveredFlags_None)
    call igGetItemRectMin(w%v_rmin)
    call igGetItemRectMax(w%v_rmax)

    ! Process mouse events
    call w%process_events_view(hover)

  end subroutine draw_view

  !> Create the texture for the view window, with atex x atex pixels.
  module subroutine create_texture_view(w,atex)
    use interfaces_opengl3
    use tools_io, only: ferror, faterr
    class(window), intent(inout), target :: w
    integer, intent(in) :: atex

    ! FBO and buffers
    call glGenTextures(1, c_loc(w%FBOtex))
    call glGenRenderbuffers(1, c_loc(w%FBOdepth))
    call glGenFramebuffers(1, c_loc(w%FBO))

    ! texture
    call glBindTexture(GL_TEXTURE_2D, w%FBOtex)
    call glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, atex, atex,&
       0, GL_RGBA, GL_UNSIGNED_BYTE, c_null_ptr)
    call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    call glBindTexture(GL_TEXTURE_2D, 0)

    ! render buffer
    call glBindRenderbuffer(GL_RENDERBUFFER, w%FBOdepth)
    call glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, atex, atex)
    call glBindRenderbuffer(GL_RENDERBUFFER, 0)

    ! frame buffer
    call glBindFramebuffer(GL_FRAMEBUFFER, w%FBO)
    call glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, w%FBOtex, 0)
    call glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, w%FBOdepth)

    ! check for errors
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) /= GL_FRAMEBUFFER_COMPLETE) &
       call ferror('window_init','framebuffer is not complete',faterr)

    ! finish and write the texture size
    call glBindFramebuffer(GL_FRAMEBUFFER, 0)
    w%FBOside = atex

  end subroutine create_texture_view

  !> Delete the texture for the view window
  module subroutine delete_texture_view(w)
    use interfaces_opengl3
    class(window), intent(inout), target :: w

    call glDeleteTextures(1, c_loc(w%FBOtex))
    call glDeleteRenderbuffers(1, c_loc(w%FBOdepth))
    call glDeleteFramebuffers(1, c_loc(w%FBO))

  end subroutine delete_texture_view

  !> Process the mouse events in the view window
  module subroutine process_events_view(w,hover)
    use interfaces_cimgui
    use scenes, only: scene
    use utils, only: translate, rotate
    use tools_math, only: cross_cfloat, matinv_cfloat
    use keybindings, only: is_bind_event, is_bind_mousescroll, BIND_NAV_ROTATE,&
       BIND_NAV_TRANSLATE, BIND_NAV_ZOOM, BIND_NAV_RESET
    use gui_main, only: io, nsys, sysc
    class(window), intent(inout), target :: w
    logical, intent(in) :: hover

    type(ImVec2) :: texpos, mousepos
    real(c_float) :: ratio, depth, pos3(3), vnew(3), vold(3), axis(3), lax
    real(c_float) :: mpos2(2), ang
    type(scene), pointer :: sc

    integer, parameter :: ilock_no = 1
    integer, parameter :: ilock_left = 2
    integer, parameter :: ilock_right = 3
    integer, parameter :: ilock_scroll = 4

    real(c_float), parameter :: mousesens_zoom0 = 0.15_c_float
    real(c_float), parameter :: mousesens_rot0 = 3._c_float
    real(c_float), parameter :: min_zoom = 1._c_float
    real(c_float), parameter :: max_zoom = 100._c_float

    type(ImVec2), save :: mposlast
    real(c_float), save :: mpos0_r(3), mpos0_l(3), cpos0_r(3), cpos0_l(3), world0(4,4)
    real(c_float), save :: world0inv(3,3), mpos0_s
    integer, save :: ilock = ilock_no

    ! first pass when opened, reset the state
    if (w%firstpass) call init_state()

    ! only process if there is an associated system is viewed and scene is initialized
    if (w%view_selected < 1 .or. w%view_selected > nsys) return
    sc => sysc(w%view_selected)%sc
    if (.not.sc%isinit) return

    ! process global events
    ! if (hover && IsBindEvent(BIND_VIEW_ALIGN_A_AXIS,false))
    !   outb |= sc->alignViewAxis(1);
    ! else if (hover && IsBindEvent(BIND_VIEW_ALIGN_B_AXIS,false))
    !   outb |= sc->alignViewAxis(2);
    ! else if (hover && IsBindEvent(BIND_VIEW_ALIGN_C_AXIS,false))
    !   outb |= sc->alignViewAxis(3);
    ! else if (hover && IsBindEvent(BIND_VIEW_ALIGN_X_AXIS,false))
    !   outb |= sc->alignViewAxis(-1);
    ! else if (hover && IsBindEvent(BIND_VIEW_ALIGN_Y_AXIS,false))
    !   outb |= sc->alignViewAxis(-2);
    ! else if (hover && IsBindEvent(BIND_VIEW_ALIGN_Z_AXIS,false))
    !   outb |= sc->alignViewAxis(-3);

    ! process mode-specific events
    if (w%view_mousebehavior == MB_Navigation) then
       call igGetMousePos(mousepos)
       texpos = mousepos

       ! transform to the texture pos
       if (abs(texpos%x) < 1e20 .and. abs(texpos%y) < 1e20) then
          call w%mousepos_to_texpos(texpos)
       end if
       ! Zoom. There are two behaviors: mouse scroll and hold key and
       ! translate mouse
       ratio = 0._c_float
       if (hover.and.(ilock == ilock_no .or. ilock == ilock_scroll).and. is_bind_event(BIND_NAV_ZOOM,.false.)) then
          if (is_bind_mousescroll(BIND_NAV_ZOOM)) then
             ! mouse scroll
             ratio = mousesens_zoom0 * io%MouseWheel
          else
             ! keys
             mpos0_s = mousepos%y
             ilock = ilock_scroll
          end if
       elseif (ilock == ilock_scroll) then
          if (is_bind_event(BIND_NAV_ZOOM,.true.)) then
             ! 10/a to make it adimensional
             ratio = mousesens_zoom0 * (mpos0_s-mousepos%y) * (10._c_float / w%FBOside)
             mpos0_s = mousepos%y
          else
             ilock = ilock_no
          end if
       end if
       if (ratio /= 0._c_float) then
          ratio = min(max(ratio,-0.99999_c_float),0.9999_c_float)

          pos3 = sc%campos - sc%scenecenter
          pos3 = pos3 - ratio * pos3
          if (norm2(pos3) < min_zoom) &
             pos3 = pos3 / norm2(pos3) * min_zoom
          if (norm2(pos3) > max_zoom * sc%scenerad) &
             pos3 = pos3 / norm2(pos3) * (max_zoom * sc%scenerad)
          sc%campos = sc%scenecenter + pos3

          call sc%update_view_matrix()
          call sc%update_projection_matrix()
          w%forcerender = .true.
       end if

       ! drag
       if (hover .and. is_bind_event(BIND_NAV_TRANSLATE,.false.) .and. (ilock == ilock_no .or. ilock == ilock_right)) then
          depth = w%texpos_viewdepth(texpos)
          if (depth < 1._c_float) then
             mpos0_r = (/texpos%x,texpos%y,depth/)
          else
             pos3 = 0._c_float
             call w%view_to_texpos(pos3)
             mpos0_r = (/texpos%x,texpos%y,pos3(3)/)
          end if
          cpos0_r = (/sc%campos(1),sc%campos(2),zero/)

          ilock = ilock_right
          mposlast = mousepos
       elseif (ilock == ilock_right) then
          call igSetMouseCursor(ImGuiMouseCursor_Hand)
          if (is_bind_event(BIND_NAV_TRANSLATE,.true.)) then
             if (mousepos%x /= mposlast%x .or. mousepos%y /= mposlast%y) then
                vnew = (/texpos%x,texpos%y,mpos0_r(3)/)
                call w%texpos_to_view(vnew)
                vold = mpos0_r
                call w%texpos_to_view(vold)

                sc%campos(1) = cpos0_r(1) - (vnew(1) - vold(1))
                sc%campos(2) = cpos0_r(2) - (vnew(2) - vold(2))
                call sc%update_view_matrix()

                mposlast = mousepos
                w%forcerender = .true.
             end if
          else
             ilock = ilock_no
          end if
       end if

       ! rotate
       if (hover .and. is_bind_event(BIND_NAV_ROTATE,.false.) .and. (ilock == ilock_no .or. ilock == ilock_left)) then
          mpos0_l = (/texpos%x, texpos%y, 0._c_float/)
          cpos0_l = mpos0_l
          call w%texpos_to_view(cpos0_l)
          ilock = ilock_left
       elseif (ilock == ilock_left) then
          call igSetMouseCursor(ImGuiMouseCursor_Hand)
          if (is_bind_event(BIND_NAV_ROTATE,.true.)) then
             if (texpos%x /= mpos0_l(1) .or. texpos%y /= mpos0_l(2)) then
                vnew = (/texpos%x,texpos%y,mpos0_l(3)/)
                call w%texpos_to_view(vnew)
                pos3 = (/0._c_float,0._c_float,1._c_float/)
                axis = cross_cfloat(pos3,vnew - cpos0_l)
                lax = norm2(axis)
                if (lax > 1e-10_c_float) then
                   axis = axis / lax
                   world0inv = sc%world(1:3,1:3)
                   call matinv_cfloat(world0inv,3)
                   axis = matmul(world0inv,axis)
                   mpos2(1) = texpos%x - mpos0_l(1)
                   mpos2(2) = texpos%y - mpos0_l(2)
                   ang = 2._c_float * norm2(mpos2) * mousesens_rot0 / w%FBOside

                   sc%world = translate(sc%world,sc%scenecenter)
                   sc%world = rotate(sc%world,ang,axis)
                   sc%world = translate(sc%world,-sc%scenecenter)

                   w%forcerender = .true.
                end if
                mpos0_l = (/texpos%x, texpos%y, 0._c_float/)
                cpos0_l = mpos0_l
                call w%texpos_to_view(cpos0_l)
             end if
          else
             ilock = ilock_no
          end if
       end if

       ! reset the view
       if (hover .and. is_bind_event(BIND_NAV_RESET,.false.)) then
          call sc%reset()
          w%forcerender = .true.
       end if
    end if

  contains
    ! initialize the state for this window
    subroutine init_state()
      mposlast%x = 0._c_float
      mposlast%y = 0._c_float
      mpos0_r = 0._c_float
      mpos0_l = 0._c_float
      cpos0_r = 0._c_float
      cpos0_l = 0._c_float
      world0 = 0._c_float
      world0inv = 0._c_float
      mpos0_s = 0._c_float
      ilock = ilock_no
    end subroutine init_state

  end subroutine process_events_view

  !> Mouse position to texture position (screen coordinates)
  module subroutine mousepos_to_texpos(w,pos)
    class(window), intent(inout), target :: w
    type(ImVec2), intent(inout) :: pos

    real(c_float) :: dx, dy, xratio, yratio

    dx = max(w%v_rmax%x - w%v_rmin%x,1._c_float)
    dy = max(w%v_rmax%y - w%v_rmin%y,1._c_float)
    xratio = 2._c_float * dx / max(dx,dy)
    yratio = 2._c_float * dy / max(dx,dy)

    pos%x = ((pos%x - w%v_rmin%x) / dx - 0.5_c_float) * xratio
    pos%y = (0.5_c_float - (pos%y - w%v_rmin%y) / dy) * yratio

    pos%x = (0.5_c_float * pos%x + 0.5_c_float) * w%FBOside
    pos%y = (0.5_c_float - 0.5_c_float * pos%y) * w%FBOside

  end subroutine mousepos_to_texpos

  !> Texture position (screen coordinates) to mouse position
  module subroutine texpos_to_mousepos(w,pos)
    class(window), intent(inout), target :: w
    type(ImVec2), intent(inout) :: pos

    real(c_float) :: x, y, xratio1, yratio1

    pos%x = (pos%x / w%FBOside) * 2._c_float - 1._c_float
    pos%y = 1._c_float - (pos%y / w%FBOside) * 2._c_float

    x = max(w%v_rmax%x - w%v_rmin%x,1._c_float)
    y = max(w%v_rmax%y - w%v_rmin%y,1._c_float)
    xratio1 = 0.5_c_float * max(x,y) / x
    yratio1 = 0.5_c_float * max(x,y) / y

    pos%x = w%v_rmin%x + x * (0.5_c_float + xratio1 * pos%x)
    pos%y = w%v_rmin%y + y * (0.5_c_float + yratio1 * pos%y)

  end subroutine texpos_to_mousepos

  !> Get the view depth from the texture position
  module function texpos_viewdepth(w,pos)
    use interfaces_opengl3
    class(window), intent(inout), target :: w
    type(ImVec2), intent(inout) :: pos
    real(c_float) :: texpos_viewdepth

    real(c_float), target :: depth

    ! pixels have the origin (0,0) at top left; the other end is bottom right, (FBOside-1,FBOside-1)
    call glBindFramebuffer(GL_FRAMEBUFFER, w%FBO)
    call glReadPixels(int(pos%x), int(w%FBOside - pos%y), 1_c_int, 1_c_int, GL_DEPTH_COMPONENT, GL_FLOAT, c_loc(depth))
    call glBindFramebuffer(GL_FRAMEBUFFER, 0)
    texpos_viewdepth = depth

  end function texpos_viewdepth

  !> Transform from view coordinates to texture position (x,y)
  !> plus depth (z).
  module subroutine view_to_texpos(w,pos)
    use utils, only: project, unproject
    use scenes, only: scene
    use gui_main, only: sysc, nsys
    class(window), intent(inout), target :: w
    real(c_float), intent(inout) :: pos(3)

    type(scene), pointer :: sc

    if (w%view_selected < 1 .or. w%view_selected > nsys) return
    sc => sysc(w%view_selected)%sc
    if (.not.sc%isinit) return

    pos = project(pos,eye4,sc%projection,w%FBOside)

  end subroutine view_to_texpos

  !> Transform texture position (x,y) plus depth (z) to view
  !> coordinates.
  module subroutine texpos_to_view(w,pos)
    use utils, only: unproject
    use scenes, only: scene
    use gui_main, only: sysc, nsys
    class(window), intent(inout), target :: w
    real(c_float), intent(inout) :: pos(3)

    type(scene), pointer :: sc

    if (w%view_selected < 1 .or. w%view_selected > nsys) return
    sc => sysc(w%view_selected)%sc
    if (.not.sc%isinit) return

    pos = unproject(pos,eye4,sc%projection,w%FBOside)

  end subroutine texpos_to_view

  !> Transform from world coordinates to texture position (x,y)
  !> plus depth (z).
  module subroutine world_to_texpos(w,pos)
    use utils, only: project
    use scenes, only: scene
    use gui_main, only: sysc, nsys
    class(window), intent(inout), target :: w
    real(c_float), intent(inout) :: pos(3)

    type(scene), pointer :: sc

    if (w%view_selected < 1 .or. w%view_selected > nsys) return
    sc => sysc(w%view_selected)%sc
    if (.not.sc%isinit) return

    pos = project(pos,sc%view,sc%projection,w%FBOside)

  end subroutine world_to_texpos

  !> Transform texture position (x,y) plus depth (z) to world
  !> coordinates.
  module subroutine texpos_to_world(w,pos)
    use utils, only: unproject
    use scenes, only: scene
    use gui_main, only: sysc, nsys
    class(window), intent(inout), target :: w
    real(c_float), intent(inout) :: pos(3)

    type(scene), pointer :: sc

    if (w%view_selected < 1 .or. w%view_selected > nsys) return
    sc => sysc(w%view_selected)%sc
    if (.not.sc%isinit) return

    pos = unproject(pos,sc%view,sc%projection,w%FBOside)

  end subroutine texpos_to_world

  !xx! edit representation

  !> Update the isys and irep in the edit represenatation window.
  module subroutine update_editrep(w)
    use windows, only: nwin, win, wintype_view
    use gui_main, only: nsys, sysc, sys_init
    class(window), intent(inout), target :: w

    integer :: isys
    logical :: doquit

    ! check the system and representation are still active
    isys = w%editrep_isys
    doquit = (isys < 1 .or. isys > nsys)
    if (.not.doquit) doquit = (sysc(isys)%status /= sys_init)
    if (.not.doquit) doquit = .not.associated(w%rep)
    if (.not.doquit) doquit = .not.w%rep%isinit
    if (.not.doquit) doquit = (w%rep%type <= 0)
    if (.not.doquit) doquit = .not.(w%editrep_iview > 0 .and. w%editrep_iview <= nwin)
    if (.not.doquit) doquit = .not.(win(w%editrep_iview)%isinit)
    if (.not.doquit) doquit = win(w%editrep_iview)%type /= wintype_view

    ! if they aren't, quit the window
    if (doquit) call w%end()

  end subroutine update_editrep

  !> Draw the edit represenatation window.
  module subroutine draw_editrep(w)
    use global, only: dunit0, iunit
    use scenes, only: representation
    use windows, only: nwin, win, wintype_view
    use keybindings, only: is_bind_event, BIND_CLOSE_FOCUSED_DIALOG, BIND_OK_FOCUSED_DIALOG
    use gui_main, only: nsys, sys, sysc, sys_init, g
    use utils, only: iw_text, iw_tooltip, iw_combo_simple, iw_button, iw_calcwidth,&
       iw_radiobutton, iw_calcheight
    use tools_io, only: string, ioj_right
    class(window), intent(inout), target :: w

    integer :: i, isys, ll, itype, iz, ispc
    logical :: doquit, ok, lshown
    logical(c_bool) :: changed, ch
    integer(c_int) :: flags
    character(len=:), allocatable :: s
    character(kind=c_char,len=:), allocatable, target :: str1, str2, str3
    character(kind=c_char,len=1024), target :: txtinp
    type(ImVec2) :: szavail, sz0
    real*8 :: x0(3)

    logical, save :: ttshown = .false. ! tooltip flag

    integer, parameter :: ic_id = 0
    integer, parameter :: ic_name = 1
    integer, parameter :: ic_z = 2
    integer, parameter :: ic_shown = 3
    integer, parameter :: ic_color = 4
    integer, parameter :: ic_radius = 5
    integer, parameter :: ic_rest = 6

    ! check the system and representation are still active
    isys = w%editrep_isys
    doquit = (isys < 1 .or. isys > nsys)
    if (.not.doquit) doquit = (sysc(isys)%status /= sys_init)
    if (.not.doquit) doquit = .not.associated(w%rep)
    if (.not.doquit) doquit = .not.w%rep%isinit
    if (.not.doquit) doquit = (w%rep%type <= 0)
    if (.not.doquit) doquit = .not.(w%editrep_iview > 0 .and. w%editrep_iview <= nwin)
    if (.not.doquit) doquit = .not.(win(w%editrep_iview)%isinit)
    if (.not.doquit) doquit = win(w%editrep_iview)%type /= wintype_view

    if (.not.doquit) then
       ! whether the rep has changed
       changed = .false.

       !!! name and type block
       call iw_text("Name and Type",highlight=.true.)

       ! the representation type
       itype = w%rep%type - 1
       call iw_combo_simple("##type","Atoms" // c_null_char // "Bonds" // c_null_char //&
          "Unit cell" // c_null_char // "Labels" // c_null_char,itype)
       if (w%rep%type /= itype + 1) changed = .true.
       w%rep%type = itype + 1
       call iw_tooltip("Type of representation",ttshown)

       ! name text input
       str1 = "##name"
       txtinp = trim(adjustl(w%rep%name)) // c_null_char
       call igSameLine(0._c_float,-1._c_float)
       if (igInputText(c_loc(str1),c_loc(txtinp),1023_c_size_t,ImGuiInputTextFlags_None,c_null_ptr,c_null_ptr)) then
          ll = index(txtinp,c_null_char)
          w%rep%name = txtinp(1:ll-1)
       end if
       call iw_tooltip("Name of this representation",ttshown)

       !!! filter
       call iw_text("Filter",highlight=.true.)
       call iw_text("(?)",sameline=.true.)
       call iw_tooltip("Explanation for the filter.")

       ! filter text input
       str1 = "##filter"
       txtinp = trim(adjustl(w%rep%filter)) // c_null_char
       if (igInputText(c_loc(str1),c_loc(txtinp),1023_c_size_t,ImGuiInputTextFlags_EnterReturnsTrue,&
          c_null_ptr,c_null_ptr)) then
          ll = index(txtinp,c_null_char)
          w%rep%filter = txtinp(1:ll-1)
          changed = .true.
       end if
       call iw_tooltip("Apply this filter to the atoms in the system. Atoms are represented if non-zero.",ttshown)
       if (iw_button("Clear",sameline=.true.)) then
          w%rep%filter = ""
          changed = .true.
       end if
       call iw_tooltip("Clear the filter",ttshown)

       !!! periodicity
       if (.not.sys(isys)%c%ismolecule) then
          call iw_text("Periodicity",highlight=.true.)

          ! radio buttons for the periodicity type
          changed = changed .or. iw_radiobutton("None",int=w%rep%pertype,intval=0_c_int)
          call iw_tooltip("Cell not repeated for this representation",ttshown)
          changed = changed .or. iw_radiobutton("Automatic",int=w%rep%pertype,intval=1_c_int,sameline=.true.)
          call iw_tooltip("Number of periodic cells controlled by the +/- options in the view menu",ttshown)
          changed = changed .or. iw_radiobutton("Manual",int=w%rep%pertype,intval=2_c_int,sameline=.true.)
          call iw_tooltip("Manually set the number of periodic cells",ttshown)

          ! number of periodic cells, if manual
          if (w%rep%pertype == 2_c_int) then
             call igPushItemWidth(5._c_float * g%FontSize)
             call iw_text("  a: ")
             call igSameLine(0._c_float,0._c_float)
             str2 = "##aaxis" // c_null_char
             changed = changed .or. igInputInt(c_loc(str2),w%rep%ncell(1),1_c_int,100_c_int,&
                ImGuiInputTextFlags_EnterReturnsTrue)
             call igSameLine(0._c_float,g%FontSize)
             call iw_text("b: ")
             call igSameLine(0._c_float,0._c_float)
             str2 = "##baxis" // c_null_char
             changed = changed .or. igInputInt(c_loc(str2),w%rep%ncell(2),1_c_int,100_c_int,&
                ImGuiInputTextFlags_EnterReturnsTrue)
             call igSameLine(0._c_float,g%FontSize)
             call iw_text("c: ")
             call igSameLine(0._c_float,0._c_float)
             str2 = "##caxis" // c_null_char
             changed = changed .or. igInputInt(c_loc(str2),w%rep%ncell(3),1_c_int,100_c_int,&
                ImGuiInputTextFlags_EnterReturnsTrue)

             w%rep%ncell = max(w%rep%ncell,1)
             if (iw_button("Reset",sameline=.true.)) then
                w%rep%ncell = 1
                changed = .true.
             end if
             call igPopItemWidth()
          end if

          ! checkbox for molecular motif
          if (sys(isys)%c%ismol3d) then
             str2 = "Show connected molecules" // c_null_char
             changed = changed .or. igCheckbox(c_loc(str2),w%rep%onemotif)
             call iw_tooltip("Translate atoms to display whole molecules",ttshown)
          end if

          ! checkbox for border
          str2 = "Show atoms at cell edges" // c_null_char
          changed = changed .or. igCheckbox(c_loc(str2),w%rep%border)
          call iw_tooltip("Display atoms near the unit cell edges",ttshown)
       end if

       !!! atom styles

       ! selector and reset
       ch = .false.
       call iw_text("Styles",highlight=.true.)
       ch = ch .or. iw_radiobutton("Species",int=w%rep%atom_style_type,intval=0_c_int)
       call iw_tooltip("Set atom styles per chemical species",ttshown)
       if (.not.sys(isys)%c%ismolecule) then
          ch = ch .or. iw_radiobutton("Symmetry-unique",int=w%rep%atom_style_type,intval=1_c_int,sameline=.true.)
          call iw_tooltip("Set atom styles per non-equivalent atom in the cell",ttshown)
          ch = ch .or. iw_radiobutton("Cell",int=w%rep%atom_style_type,intval=2_c_int,sameline=.true.)
          call iw_tooltip("Set atom styles per atom in the unit cell",ttshown)
       else
          ch = ch .or. iw_radiobutton("Atoms",int=w%rep%atom_style_type,intval=1_c_int,sameline=.true.)
          call iw_tooltip("Set atom styles per atom in the molecule",ttshown)
       end if
       if (ch) then
          call w%rep%reset_atom_style()
          changed = .true.
       end if

       ! atom style table
       flags = ImGuiTableFlags_None
       flags = ior(flags,ImGuiTableFlags_Resizable)
       flags = ior(flags,ImGuiTableFlags_Reorderable)
       flags = ior(flags,ImGuiTableFlags_NoSavedSettings)
       flags = ior(flags,ImGuiTableFlags_Borders)
       flags = ior(flags,ImGuiTableFlags_SizingFixedFit)
       flags = ior(flags,ImGuiTableFlags_ScrollY)
       str1="##tableatomstyles"
       sz0%x = 0
       sz0%y = iw_calcheight(min(5,w%rep%natom_style)+1,0,.false.)
       if (igBeginTable(c_loc(str1),7,flags,sz0,0._c_float)) then
          ! header setup
          str2 = "Id" // c_null_char
          flags = ImGuiTableColumnFlags_None
          call igTableSetupColumn(c_loc(str2),flags,0.0_c_float,ic_id)

          str2 = "Atom" // c_null_char
          flags = ImGuiTableColumnFlags_None
          call igTableSetupColumn(c_loc(str2),flags,0.0_c_float,ic_name)

          str2 = "Z" // c_null_char
          flags = ImGuiTableColumnFlags_None
          call igTableSetupColumn(c_loc(str2),flags,0.0_c_float,ic_z)

          str2 = "Show" // c_null_char
          flags = ImGuiTableColumnFlags_None
          call igTableSetupColumn(c_loc(str2),flags,0.0_c_float,ic_shown)

          str2 = "Color" // c_null_char
          flags = ImGuiTableColumnFlags_None
          call igTableSetupColumn(c_loc(str2),flags,0.0_c_float,ic_color)

          str2 = "Radius" // c_null_char
          flags = ImGuiTableColumnFlags_None
          call igTableSetupColumn(c_loc(str2),flags,0.0_c_float,ic_radius)

          str2 = "Coordinates" // c_null_char
          flags = ImGuiTableColumnFlags_WidthStretch
          call igTableSetupColumn(c_loc(str2),flags,0.0_c_float,ic_rest)
          call igTableSetupScrollFreeze(0, 1) ! top row always visible

          ! draw the header
          call igTableHeadersRow()
          call igTableSetColumnWidthAutoAll(igGetCurrentTable())

          ! draw the raws
          do i = 1, w%rep%natom_style
             call igTableNextRow(ImGuiTableRowFlags_None, 0._c_float)
             if (w%rep%atom_style_type == 0) then
                ! species
                ispc = i
             elseif (w%rep%atom_style_type == 1) then
                ! nneq
                ispc = sys(isys)%c%at(i)%is
             elseif (w%rep%atom_style_type == 2) then
                ! ncel
                ispc = sys(isys)%c%atcel(i)%is
             end if
             iz = sys(isys)%c%spc(ispc)%z

             ! id
             if (igTableSetColumnIndex(ic_id)) call iw_text(string(i))

             ! name
             if (igTableSetColumnIndex(ic_name)) call iw_text(string(sys(isys)%c%spc(ispc)%name))

             ! Z
             if (igTableSetColumnIndex(ic_z)) call iw_text(string(iz))

             ! shown
             if (igTableSetColumnIndex(ic_shown)) then
                str2 = "##shown" // string(i) // c_null_char
                changed = changed .or. igCheckbox(c_loc(str2),w%rep%atom_style(i)%shown)
             end if

             ! color
             if (igTableSetColumnIndex(ic_color)) then
                str2 = "##color" // string(i) // c_null_char
                flags = ior(ImGuiColorEditFlags_NoInputs,ImGuiColorEditFlags_NoLabel)
                ch = igColorEdit4(c_loc(str2),w%rep%atom_style(i)%rgba,flags)
                if (ch) then
                   w%rep%atom_style(i)%rgba = min(w%rep%atom_style(i)%rgba,1._c_float)
                   w%rep%atom_style(i)%rgba = max(w%rep%atom_style(i)%rgba,0._c_float)
                   changed = .true.
                end if
             end if

             ! radius
             if (igTableSetColumnIndex(ic_radius)) then
                str2 = "##radius" // string(i) // c_null_char
                str3 = "%.3f" // c_null_char
                call igPushItemWidth(iw_calcwidth(5,1))
                ch = ch .or. igInputFloat(c_loc(str2),w%rep%atom_style(i)%rad,0._c_float,&
                   0._c_float,c_loc(str3),ImGuiInputTextFlags_EnterReturnsTrue)
                if (ch) then
                   w%rep%atom_style(i)%rad = max(w%rep%atom_style(i)%rad,0._c_float)
                   changed = .true.
                end if
                call igPopItemWidth()
             end if

             ! rest of info
             if (igTableSetColumnIndex(ic_rest)) then
                s = ""
                if (w%rep%atom_style_type > 0) then
                   if (sys(isys)%c%ismolecule) then
                      x0 = (sys(isys)%c%atcel(i)%r+sys(isys)%c%molx0) * dunit0(iunit)
                   elseif (w%rep%atom_style_type == 1) then
                      x0 = sys(isys)%c%at(i)%x
                   elseif (w%rep%atom_style_type == 2) then
                      x0 = sys(isys)%c%atcel(i)%x
                   endif
                   s = string(x0(1),'f',7,4,ioj_right) //" "// string(x0(2),'f',7,4,ioj_right) //" "//&
                      string(x0(3),'f',7,4,ioj_right)
                end if
                call iw_text(s)
             end if
          end do
          call igEndTable()
       end if

       ! style buttons: show/hide
       if (iw_button("Show All")) &
          w%rep%atom_style(1:w%rep%natom_style)%shown = .true.
       call iw_tooltip("Show all atoms in the system",ttshown)
       if (iw_button("Hide All",sameline=.true.)) &
          w%rep%atom_style(1:w%rep%natom_style)%shown = .false.
       call iw_tooltip("Hide all atoms in the system",ttshown)
       if (iw_button("Toggle Show/Hide",sameline=.true.)) then
          do i = 1, w%rep%natom_style
             w%rep%atom_style(i)%shown = .not.w%rep%atom_style(i)%shown
          end do
       end if
       call iw_tooltip("Toggle the show/hide status for all atoms",ttshown)

       ! render if necessary
       if (changed) win(w%editrep_iview)%forcerender = .true.

       ! right-align and bottom-align for the rest of the contents
       call igGetContentRegionAvail(szavail)
       call igSetCursorPosX(iw_calcwidth(7,2,from_end=.true.))
       call igSetCursorPosY(igGetCursorPosY() + szavail%y - igGetTextLineHeightWithSpacing() - g%Style%WindowPadding%y)

       ! reset button
       if (iw_button("Reset",danger=.true.)) then
          str2 = w%rep%name
          itype = w%rep%type
          lshown = w%rep%shown
          call w%rep%init(w%rep%id,w%rep%idrep,itype)
          w%rep%name = str2
          w%rep%shown = lshown
          win(w%editrep_iview)%forcerender = .true.
       end if

       ! close button
       ok = (w%focused() .and. is_bind_event(BIND_OK_FOCUSED_DIALOG))
       ok = ok .or. iw_button("OK",sameline=.true.)
       if (ok) then
          win(w%editrep_iview)%forcerender = .true.
          doquit = .true.
       end if
    end if

    ! exit if focused and received the close keybinding
    if (w%focused() .and. is_bind_event(BIND_CLOSE_FOCUSED_DIALOG)) doquit = .true.

    if (doquit) then
       call w%end()
    end if

  end subroutine draw_editrep

end submodule view
