module vertical_model
!23456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012!

    !==============================================================
    ! This code is part of MOLECULAR_TOOLS 
    !==============================================================
    ! Description
    !  This MODULE contains subroutines with macros useful for
    !  frequency analysis on non-stationary points
    ! 
    !==============================================================

    !Common declarations:
    !===================
    use matrix
    use matrix_print
    use verbosity
    use constants
    use alerts
    use structure_types
    use symmetry

    implicit none

    contains

    subroutine check_symm_gsBder(molecule,gsBder)

        !==============================================================
        ! This code is part of MOLECULAR_TOOLS
        !==============================================================
        !Description
        ! Diagonalizes a Hessian after mass-weighing and translation to 
        ! the internal frame defined by satifying the Eckart-Saytvez conditions.
        !
        !Arguments
        ! Nat     (inp) int /scalar   Number of atoms
        ! Nvib    (inp) int /scalar   Number of vibrational degrees of freedom
        ! X,Y,Z   (inp) real/vectors  Coordinate vectors (ANGSTRONG)
        ! Mass    (inp) real/vector   Atomic masses (AMU)
        ! Freq    (inp) real/vector   Frequencies (cm-1)
        !
        !
        !==============================================================

        type(str_resmol),intent(inout)       :: molecule
        real(8),dimension(:,:),intent(in)    :: gsBder

        !Local
        integer,parameter :: NDIM = 600

        character(len=5) :: PG_current
        integer,dimension(1:NDIM) :: isym
        integer,dimension(1:4,1:NDIM,1:NDIM) :: Osym
        integer :: Nsym, Nat
        !Counters
        integer :: iop, i, j
        ! Aux scalar and matrix
        real(8) :: Theta, Theta2
        real(8),dimension(NDIM,NDIM) :: Aux

        Nat = molecule%natoms

        print'(/,X,A)', "---------------------------------------"
        print'(X,A  )', " Check effect of symmetry operations"
        print'(X,A  )', " on the correction term gs^t\beta"
        print'(X,A  )', "---------------------------------------"
        PG_current = molecule%PG
        molecule%PG="XX"
        call symm_atoms(molecule,isym,Osym,rotate=.false.,nsym_ops=nsym)
        ! Check the symmetry of the correction term
        ! Check all detected symmetry ops
        do iop=1,Nsym
            Aux(1:3*Nat,1:3*Nat) = dfloat(Osym(iop,1:3*Nat,1:3*Nat))
            Aux(1:3*Nat,1:3*Nat) = matrix_basisrot(3*Nat,3*Nat,Aux,gsBder,counter=.true.)
            Theta=0.d0
            do i=1,3*Nat 
            do j=1,3*Nat 
                if (Theta < abs(Aux(i,j)-gsBder(i,j))) then
                    Theta = abs(Aux(i,j)-gsBder(i,j))
                    Theta2=gsBder(i,j)
                endif
            enddo
            enddo
            print'(X,A,I0)', "Symmetry operation :   ", iop
            print'(X,A,F10.6)',   " Max abs difference : ", Theta
            print'(X,A,F10.6,/)', " Value before sym op: ", Theta2
        enddo
        print'(X,A,/)', "---------------------------------------"

        molecule%PG = PG_current

        return

    end subroutine check_symm_gsBder

    function projection_matrix(Nat,Ns,B) result(P)

        !==============================================================
        ! This code is part of MOLECULAR_TOOLS
        !==============================================================
        !Description
        ! Diagonalizes a Hessian after mass-weighing and translation to 
        ! the internal frame defined by satifying the Eckart-Saytvez conditions.
        !
        !Arguments
        ! Nat     (inp) int /scalar   Number of atoms
        ! Ns      (inp) int /scalar   Number of internal coordinates
        !
        !
        !==============================================================

        integer,intent(in)                 :: Nat, Ns
        real(8),dimension(:,:),intent(in)  :: B
        real(8),dimension(3*Nat,3*Nat)     :: P

        !Local
        integer,parameter :: NDIM = 600

        real(8),dimension(NDIM,NDIM) :: Aux

        Aux(1:Ns,1:Ns)     = matrix_product(Ns,Ns,3*Nat,B,B,tB=.true.)
        Aux(1:Ns,1:Ns)     = inverse_realgen(Ns,Aux)
        Aux(1:3*Nat,1:Ns)  = matrix_product(3*Nat,Ns,Ns,B,Aux,tA=.true.)
        P(1:3*Nat,1:3*Nat) = matrix_product(3*Nat,3*Nat,Ns,Aux,B)

        return

    end function projection_matrix


    function projection_matrix2(Nat,X,Y,Z,Mass) result(P)

        !==============================================================
        ! This code is part of MOLECULAR_TOOLS
        !==============================================================
        !Description
        ! Diagonalizes a Hessian after mass-weighing and translation to 
        ! the internal frame defined by satifying the Eckart-Saytvez conditions.
        !
        !Arguments
        ! Nat     (int) int /scalar   Number of atoms
        ! X,Y,Z   (inp) real/vectors  Coordinate vectors (ANGSTRONG)
        ! Mass    (inp) real/vector   Atomic masses (AMU)        !
        !          
        !Notes
        !==============================================================

        !Approximate zero
        real(kind=8),parameter :: ZERO=1.d-10

        integer,intent(in)                      :: Nat
        real(8),dimension(:),intent(in)         :: X,Y,Z
        real(8),dimension(:),intent(in)         :: Mass
        real(8),dimension(1:3*Nat,1:3*Nat)      :: P

        !Local
        ! Counters
        integer :: i, j, k, ii, jj
        integer :: Nrt
        integer :: error_local
        ! Auxiliar scalars and arrays
        real(kind=8)                :: pes, MassTot, angle
        real(kind=8),dimension(1:3)   :: R, RCOM
        real(kind=8),dimension(1:3,1:3) :: MI, Xrot
        real(kind=8),dimension(1:3*Nat,6) :: D
        real(kind=8),dimension(1:3*Nat,1:3*Nat)   :: T
        real(kind=8),dimension(1:Nat)             :: Mass_local, Freq


        !Working in AU: transform mass to AU
        Mass_local(1:Nat) = Mass(1:Nat) * AMUtoAU

        ! Compute rotation matrix to the Eckart frame
            
        !Get COM 
        RCOM(1:3) = 0.d0
        MassTot   = 0.d0
        do i=1,Nat
            RCOM(1) = RCOM(1) + X(i)*Mass_local(i)
            RCOM(2) = RCOM(2) + Y(i)*Mass_local(i)
            RCOM(3) = RCOM(3) + Z(i)*Mass_local(i)
            MassTot = MassTot + Mass_local(i)
        enddo
        RCOM(1:3) = RCOM(1:3)/MassTot
        
        !Get moment of intertia
        MI=0.d0
        do i=1,Nat
            R=(/X(i)-RCOM(1),Y(i)-RCOM(2),Z(i)-RCOM(3)/)
            !diag
            MI(1,1)=MI(1,1)+Mass_local(i)*(R(2)**2+R(3)**2)
            MI(2,2)=MI(2,2)+Mass_local(i)*(R(1)**2+R(3)**2)
            MI(3,3)=MI(3,3)+Mass_local(i)*(R(1)**2+R(2)**2)
            !off-diag
            MI(2,1)=MI(2,1)-Mass_local(i)*(R(2)*R(1))
            MI(3,1)=MI(3,1)-Mass_local(i)*(R(3)*R(1))
            MI(3,2)=MI(3,2)-Mass_local(i)*(R(3)*R(2))
        enddo
        do i=1,3
          do j=1,i-1
              MI(j,i) = MI(i,j)
          enddo
        enddo
        
        !Diagonalize to get the rotation to the principal axes
        call diagonalize_full(MI(1:3,1:3),3,Xrot(1:3,1:3),Freq(1:3),"lapack")
        ! MI = Xrot^t * Freq * Xrot
        !Note we need to transpose to follow G09 white paper
        Xrot=transpose(Xrot)
        
        !Get the orthogonal transformation to the internal frame
        ! we follow G09 white paper
        ! Note that there is a typo:
        !  * Rotational coordinates should have m^1/2 factor multiplied, not divided
        ! Furthermore, there additional issues are  
        !  * Confusing  matrix indices. Note that X should be transposed first to use the
        !    order they use
        D(1:3*Nat,1:6) = 0.d0
        !Traslation
        do i=1,3*Nat,3
            j=(i-1)/3+1
            !D(1)
            D(i  ,1) = dsqrt(Mass_local(j)) 
            !D(2)
            D(i+1,2) = dsqrt(Mass_local(j)) 
            !D(3)
            D(i+2,3) = dsqrt(Mass_local(j)) 
        enddo
        !Normalize
        D(1:3*Nat,1) = D(1:3*Nat,1)/dsqrt(vector_dot_product(3*Nat,D(1:3*Nat,1),D(1:3*Nat,1)))
        D(1:3*Nat,2) = D(1:3*Nat,2)/dsqrt(vector_dot_product(3*Nat,D(1:3*Nat,2),D(1:3*Nat,2)))
        D(1:3*Nat,3) = D(1:3*Nat,3)/dsqrt(vector_dot_product(3*Nat,D(1:3*Nat,3),D(1:3*Nat,3)))
        
        !Rotation
        do i=1,3*Nat,3
            j=(i-1)/3+1
            !Get Equil. coordinates in the principal axis frame 
            R=(/X(j)-RCOM(1),Y(j)-RCOM(2),Z(j)-RCOM(3)/)
            R(1:3) = matmul(Xrot(1:3,1:3),R(1:3))
            !D(4)
            D(i  ,4) = (R(2)*Xrot(3,1) - R(3)*Xrot(2,1))*dsqrt(Mass_local(j)) 
            D(i+1,4) = (R(2)*Xrot(3,2) - R(3)*Xrot(2,2))*dsqrt(Mass_local(j)) 
            D(i+2,4) = (R(2)*Xrot(3,3) - R(3)*Xrot(2,3))*dsqrt(Mass_local(j)) 
            !D(5)
            D(i  ,5) = (R(3)*Xrot(1,1) - R(1)*Xrot(3,1))*dsqrt(Mass_local(j)) 
            D(i+1,5) = (R(3)*Xrot(1,2) - R(1)*Xrot(3,2))*dsqrt(Mass_local(j)) 
            D(i+2,5) = (R(3)*Xrot(1,3) - R(1)*Xrot(3,3))*dsqrt(Mass_local(j)) 
            !D(5)
            D(i  ,6) = (R(1)*Xrot(2,1) - R(2)*Xrot(1,1))*dsqrt(Mass_local(j)) 
            D(i+1,6) = (R(1)*Xrot(2,2) - R(2)*Xrot(1,2))*dsqrt(Mass_local(j)) 
            D(i+2,6) = (R(1)*Xrot(2,3) - R(2)*Xrot(1,3))*dsqrt(Mass_local(j)) 
        enddo
        !Normalize (and determine if there is one equal to zero: linear molecules)
        ii = 3
        do i=4,6 
            ii = ii + 1
            pes=vector_dot_product(3*Nat,D(1:3*Nat,ii),D(1:3*Nat,ii))
            if (abs(pes) < ZERO) then
                print*, "NOTE: linear molecule detected"
                !Shift comlumns
                do j=ii,5
                    D(1:3*Nat,j) = D(1:3*Nat,j+1)
                enddo
                ii = ii - 1
            else
                D(1:3*Nat,ii) = D(1:3*Nat,ii)/dsqrt(pes)
            endif
        enddo
        Nrt = ii
        if (Nrt < 5) then
            print*, "ERROR: invalid number of Tras+Rot", Nrt
            stop
        endif

        ! Build identity matrix for initial P
        P(1:3*Nat,1:3*Nat) = 0.d0
        do i=1,3*Nat 
            P(i,i) = 1.d0
        enddo

        ! And remove translations and rotations
        do i=1,Nrt
            ! Compute "metric matrix" for coordinate i
            do ii=1,3*Nat
            do jj=1,3*Nat
                T(ii,jj) = D(ii,i)*D(jj,i) 
            enddo 
            enddo
            ! And remove from P
            P(1:3*Nat,1:3*Nat) = P(1:3*Nat,1:3*Nat) - T(1:3*Nat,1:3*Nat)
        enddo

        return

    end function projection_matrix2

end module vertical_model