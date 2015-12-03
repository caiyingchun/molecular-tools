module symmetry

    !CAUTION: UNCHECKED MODULE (14/11/2012)

    implicit none

    contains

!    !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! 
!     subroutine symm_atoms_old(molec,isym)
! 
!         use structure_types
!         use alerts
!         use matrix
!         use molecular_structure, only: rotate_molec
! 
!         !System variables
!         type(str_resmol),intent(inout) :: molec
!         integer,dimension(:),intent(out) :: isym
! 
!         real(8) :: X_COM, Y_COM, Z_COM, dist, x_sym, y_sym, z_sym, Mass
!         real(8),dimension(3,3) :: Rot, MI
!         real(8),dimension(3) :: R
! 
!         !local
!         integer :: i,j
!         type(str_resmol) :: molec
! 
! 
!         ! FIRST PLACE THE MOLECULE ON THE COM
!         molec = molec
!         !====================
!         !Center of Masses
!         !====================
!         X_COM=0.d0
!         Y_COM=0.d0
!         Z_COM=0.d0
!         Mass =0.d0
!         do i=1,molec%natoms
!             X_COM=X_COM+molec%atom(i)%x
!             Y_COM=Y_COM+molec%atom(i)%y
!             Z_COM=Z_COM+molec%atom(i)%z
!             Mass = Mass+ molec%atom(i)%mass
!         enddo
!         X_COM=X_COM/Mass
!         Y_COM=Y_COM/Mass
!         Z_COM=Z_COM/Mass
!         ! Translate
!         do i=1,molec%natoms
!             molec%atom(i)%x = molec%atom(i)%x - X_COM
!             molec%atom(i)%y = molec%atom(i)%y - Y_COM
!             molec%atom(i)%z = molec%atom(i)%z - Z_COM
!         enddo
! 
!         ! Axes...
!         !Get moment of intertia
!         MI=0.d0
!         do i=1,molec%natoms
!             R=(/molec%atom(i)%x,molec%atom(i)%y,molec%atom(i)%z/)
!             !diag
!             MI(1,1)=MI(1,1)+molec%atom(i)%mass*(R(2)**2+R(3)**2)
!             MI(2,2)=MI(2,2)+molec%atom(i)%mass*(R(1)**2+R(3)**2)
!             MI(3,3)=MI(3,3)+molec%atom(i)%mass*(R(1)**2+R(2)**2)
!             !off-diag
!             MI(2,1)=MI(2,1)-molec%atom(i)%mass*(R(2)*R(1))
!             MI(3,1)=MI(3,1)-molec%atom(i)%mass*(R(3)*R(1))
!             MI(3,2)=MI(3,2)-molec%atom(i)%mass*(R(3)*R(2))
!        enddo
!        do i=1,3
!           do j=1,i-1
!               MI(j,i) = MI(i,j)
!           enddo
!         enddo
!         !Diagonalize to get the rotation to the principal axes
!         call diagonalize_full(MI(1:3,1:3),3,Rot(1:3,1:3),R(1:3),"lapack")
!         ! And rotate
!         call rotate_molec(molec,Rot)
! 
! 
!         !==================
!         !Use symmetry 
!         !==================
!         if ( molec%PG(1:2) == "CI" ) then
!         
!             do i=1,molec%natoms
!                 x_sym=-molec%atom(i)%x
!                 y_sym=-molec%atom(i)%y
!                 z_sym=-molec%atom(i)%z
! 
!                 !Search the atom located at the symmetric position (with a given threshold)
!                 do j=1,molec%natoms
!                     dist=dsqrt((molec%atom(j)%x-x_sym)**2+(molec%atom(j)%y-y_sym)**2+(molec%atom(j)%z-z_sym)**2)
!                     if ( dist < 1d-3 ) then
!                         isym(i)=j
!                         exit
!                     endif
!                 enddo
! 
!             enddo
! 
!         else
!             call alert_msg("note","This kind of symmetry in not supported (yet): "//molec%PG)
! 
!         endif
! 
! 
!         return
! 
!     end subroutine symm_atoms_old


    subroutine symm_atoms(molec,isym)

        !This routine also try to guess the symmetry (only Ci and C2 along Cartesian axis, for the moment)
        ! (in compatible with the old routine calls, so this is taken as default)
        ! Multiple symmetries can be simultaneously detected, thus identifying 
        ! several equivalent atoms. The output (isym) only reports the atom with
        ! the lower serial number.

        use structure_types
        use alerts
        use matrix, only:sort_vec_int, diagonalize_full
        use molecular_structure

        real(8),parameter :: THRS=1.d-1 !loose

        !System variables
        type(str_resmol),intent(inout)   :: molec
        integer,dimension(:),intent(out) :: isym
        integer,dimension(200,10)        :: isym_v2

        double precision :: X_COM, Y_COM, Z_COM, dist, x_sym, y_sym, z_sym, Mass
        logical :: located

        !local
        integer :: i,j, nsym
!         type(str_resmol) :: molec_local
        real(8),dimension(:),allocatable :: X0,Y0,Z0
        real(8),dimension(3,3) :: Rot, MI
        real(8),dimension(3) :: R
        integer :: Nat

        !Save original coordinates
        Nat=molec%natoms
        allocate(X0(1:Nat),Y0(1:Nat),Z0(1:Nat))
        X0=molec%atom(1:Nat)%x
        Y0=molec%atom(1:Nat)%y
        Z0=molec%atom(1:Nat)%z

        ! FIRST PLACE THE MOLECULE ON THE COM
        !====================
        !Center of Masses
        !====================
        call get_com(molec)
        ! Translate
        do i=1,molec%natoms
            molec%atom(i)%x = molec%atom(i)%x - molec%comX
            molec%atom(i)%y = molec%atom(i)%y - molec%comY
            molec%atom(i)%z = molec%atom(i)%z - molec%comZ
        enddo

        !====================
        !Axes of intertia
        !====================
        !Get moment of intertia
        call inertia(molec,MI)
        !Diagonalize to get the rotation to the principal axes
        call diagonalize_full(MI(1:3,1:3),3,Rot(1:3,1:3),R(1:3),"lapack")
        ! And rotate
        Rot=transpose(Rot)
        call rotate_molec(molec,Rot)


        !==================
        !Use symmetry (note: only the main symmetry element is used!)
        !==================
        if ( molec%PG(1:2) == "CI" ) then
        
            do i=1,molec%natoms
                x_sym=-molec%atom(i)%x
                y_sym=-molec%atom(i)%y
                z_sym=-molec%atom(i)%z

                !Search the atom located at the symmetric position (with a given threshold)
                do j=1,molec%natoms
                    dist=dsqrt((molec%atom(j)%x-x_sym)**2+(molec%atom(j)%y-y_sym)**2+(molec%atom(j)%z-z_sym)**2)
!                     if ( dist < 1d-3 ) then
                    if ( dist < THRS ) then
                        isym(i)=j
                        exit
                    endif
                enddo

            enddo

        elseif ( molec%PG(1:3) == "C02" ) then
        
            do i=1,molec%natoms
                !Only works if C2 is the Z axis (default for standard orientation)
                x_sym=-molec%atom(i)%x
                y_sym=-molec%atom(i)%y
                z_sym=molec%atom(i)%z

                !Search the atom located at the symmetric position (with a given threshold)
                do j=1,molec%natoms
                    dist=dsqrt((molec%atom(j)%x-x_sym)**2+(molec%atom(j)%y-y_sym)**2+(molec%atom(j)%z-z_sym)**2)
!                     if ( dist < 1d-3 ) then
                    if ( dist < THRS ) then
                        isym(i)=j
                        exit
                    endif
                enddo

            enddo

        elseif ( molec%PG(1:2) == "XX" ) then
        !All possible symmetry elements are used
            nsym = 0

            ! CI
            !If there is an equivalent atom at -r, is CI symmetry (at least)
            nsym = nsym+1
            do i=1,molec%natoms
                located=.false.
                x_sym=-molec%atom(i)%x
                y_sym=-molec%atom(i)%y
                z_sym=-molec%atom(i)%z

                !Search the atom located at the symmetric position (with a given threshold)
                do j=1,molec%natoms
                    dist=dsqrt((molec%atom(j)%x-x_sym)**2+(molec%atom(j)%y-y_sym)**2+(molec%atom(j)%z-z_sym)**2)
                    if ( dist < THRS ) then
                        located=.true.
                        isym(i)=j
                        isym_v2(i,nsym)=j
                        exit
                    endif
                enddo
                if (.not.located) exit

            enddo
            if (located) then
                 print*, ""
                 print*, "CI symmetry element found"
                 molec%PG="CI"   
!                  return
            else
                 nsym = nsym-1
            endif

            ! C2
            !Only works if C2 is the Z axis (default for standard orientation)
            nsym = nsym+1
            do i=1,molec%natoms
                located=.false.
                x_sym=-molec%atom(i)%x
                y_sym=-molec%atom(i)%y
                z_sym=molec%atom(i)%z

                !Search the atom located at the symmetric position (with a given threshold)
                do j=1,molec%natoms
                    dist=dsqrt((molec%atom(j)%x-x_sym)**2+(molec%atom(j)%y-y_sym)**2+(molec%atom(j)%z-z_sym)**2)
                    if ( dist < THRS ) then
                        located=.true.
                        isym(i)=j
                        isym_v2(i,nsym)=j
                        exit
                    endif
                enddo
                if (.not.located) exit

            enddo
            if (located) then
!                  nsym = nsym+1
                 print*, ""
                 print*, "C02(z) symmetry element found"
                 molec%PG="C02"   
!                  return
            else
                 nsym = nsym-1
            endif

            ! C2 along Y axis
            nsym = nsym+1
            do i=1,molec%natoms
                located=.false.
                x_sym=-molec%atom(i)%x
                y_sym=molec%atom(i)%y
                z_sym=-molec%atom(i)%z

                !Search the atom located at the symmetric position (with a given threshold)
                do j=1,molec%natoms
                    dist=dsqrt((molec%atom(j)%x-x_sym)**2+(molec%atom(j)%y-y_sym)**2+(molec%atom(j)%z-z_sym)**2)
                    if ( dist < THRS ) then
                        located=.true.
                        isym(i)=j
                        isym_v2(i,nsym)=j
                        exit
                    endif
                enddo
                if (.not.located) exit

            enddo
            if (located) then
                 print*, ""
                 print*, "C02(y) symmetry element found"
                 molec%PG="C02"   
!                  return
            else
                 nsym = nsym-1
            endif

            ! C2 along X axis
            nsym = nsym+1
            do i=1,molec%natoms
                located=.false.
                x_sym=molec%atom(i)%x
                y_sym=-molec%atom(i)%y
                z_sym=-molec%atom(i)%z

                !Search the atom located at the symmetric position (with a given threshold)
                do j=1,molec%natoms
                    dist=dsqrt((molec%atom(j)%x-x_sym)**2+(molec%atom(j)%y-y_sym)**2+(molec%atom(j)%z-z_sym)**2)
                    if ( dist < THRS ) then
                        located=.true.
                        isym(i)=j
                        isym_v2(i,nsym)=j
                        exit
                    endif
                enddo
                if (.not.located) exit

            enddo
            if (located) then
                 print*, ""
                 print*, "C02(x) symmetry element found"
                 molec%PG="C02"   
!                  return
            else
                 nsym = nsym-1
            endif
 
            !No sym found
            if (nsym == 0) then
                call alert_msg("note","Cannot determine symmetry. Set to C1 (no symmetric atoms)")
                do i=1,molec%natoms
                    isym(i) = i
                enddo
                molec%PG="C1"
            else
                do i=1,molec%natoms
                    call sort_vec_int(isym_v2(i,1:nsym),nsym)
                    isym(i) = isym_v2(i,1)
                enddo
            endif
            print*, ""


            !Higher symmetry groups shuld also be test... (TODO)
            

        else
            call alert_msg("note","This kind of symmetry in not supported (yet): "//molec%PG)

        endif

        ! Restore original coordinates
        molec%atom(1:Nat)%x=X0
        molec%atom(1:Nat)%y=Y0
        molec%atom(1:Nat)%z=Z0
        deallocate(X0,Y0,Z0)


        return

    end subroutine symm_atoms



end module symmetry