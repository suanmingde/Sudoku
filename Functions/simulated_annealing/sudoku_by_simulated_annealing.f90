MODULE CONSTANTS

  IMPLICIT NONE
  INTEGER, PARAMETER :: DBLE_PREC = KIND(0.0D0)
  REAL(KIND=DBLE_PREC), PARAMETER :: ZERO  = 0.0_DBLE_PREC
  REAL(KIND=DBLE_PREC), PARAMETER :: ONE   = 1.0_DBLE_PREC
  REAL(KIND=DBLE_PREC), PARAMETER :: TWO   = 2.0_DBLE_PREC
  REAL(KIND=DBLE_PREC), PARAMETER :: THREE = 3.0_DBLE_PREC
  REAL(KIND=DBLE_PREC), PARAMETER :: FOUR  = 4.0_DBLE_PREC

END MODULE CONSTANTS

MODULE SIMULATED_ANNEALING
  
  USE CONSTANTS
  
CONTAINS
  
  SUBROUTINE INDEX_MAP(INDEX_VECTOR, INDEX)
    IMPLICIT NONE
    INTEGER :: INDEX_VECTOR(3), INDEX
    INDEX = INDEX_VECTOR(1) + 9*(INDEX_VECTOR(2)-1) + 81*(INDEX_VECTOR(3)-1)
  END SUBROUTINE INDEX_MAP
  
  SUBROUTINE LOSS(P, C, N_VIOLATIONS)
    IMPLICIT NONE
    INTEGER :: P(:), C(:,:), N_VIOLATIONS
    INTEGER :: I, N, SCORES(SIZE(C,1))
    SCORES = MATMUL(C, P)
    N = SIZE(SCORES)
    N_VIOLATIONS = 0
    DO I = 1,N
       IF (SCORES(I) .NE. 1) THEN
          N_VIOLATIONS = N_VIOLATIONS + 1
       END IF
    END DO
  END SUBROUTINE LOSS
  
  SUBROUTINE MAKE_BOARD(X, Y, BOARD)
    IMPLICIT NONE
    INTEGER :: X(:,:), Y(:,:), BOARD(:,:), I, J, N, M
    N = SIZE(X,1)
    DO M = 1,N
       I = X(M,1)
       J = X(M,2)
       BOARD(I,J) = X(M,3)
    END DO
    N = SIZE(Y,1)
    DO M=1,N
       I = Y(M,1)
       J = Y(M,2)
       BOARD(I,J) = Y(M,3)
    END DO
  END SUBROUTINE MAKE_BOARD

  ! Assign probabilities to constraints proportional to the deviation from one.
  SUBROUTINE GENERATE_PROBABILITIES(X, Y, PROB)
    IMPLICIT NONE
    INTEGER :: X(:,:), Y(:,:), BOARD(9,9), N, &
         N_VIOLATIONS(SIZE(Y,1)), I, R, C, VALUE, TALLY, &
         IXROW(3), IXCOL(3), J, K
    REAL(KIND=DBLE_PREC) :: PROB(:)
    LOGICAL :: FLAG
    N = SIZE(Y,1)
    N_VIOLATIONS = 0
    CALL MAKE_BOARD(X, Y, BOARD)
    DO I = 1,N
       R = Y(I,1)
       C = Y(I,2)
       VALUE = Y(I,3)
       ! Check row violations
       TALLY = 0
       DO J = 1,9
          IF (BOARD(R,J) .EQ. VALUE) THEN
             TALLY = TALLY + 1
          END IF
       END DO
       IF (TALLY > 1) THEN
          N_VIOLATIONS(I) = N_VIOLATIONS(I) + 1
       END IF
       ! Check column violations
       TALLY = 0
       DO J = 1,9
          IF (BOARD(J,C) .EQ. VALUE) THEN
             TALLY = TALLY + 1
          END IF
       END DO
       IF (TALLY > 1) THEN
          N_VIOLATIONS(I) = N_VIOLATIONS(I) + 1
       END IF
       ! Check region violations
       FLAG = .TRUE.
       IXROW = (/ 1, 2, 3 /)
       DO
          DO J = 1,3
             IF (R .EQ. IXROW(J)) THEN
                FLAG = .FALSE.
                EXIT
             END IF
          END DO
          IF (FLAG) THEN
             IXROW = IXROW + 3
          ELSE 
             EXIT
          END IF
       END DO
       IXCOL = (/ 1, 2, 3 /)
       FLAG = .TRUE.
       DO
          DO J = 1,3
             IF (C .EQ. IXCOL(J)) THEN
                FLAG = .FALSE.
                EXIT
             END IF
          END DO
          IF (FLAG) THEN
             IXCOL = IXCOL + 3
          ELSE 
             EXIT
          END IF
       END DO
       TALLY = 0
       DO J = 1,3
          DO K = 1,3
             IF (BOARD(IXROW(J),IXCOL(K)) .EQ. VALUE) THEN
                TALLY = TALLY + 1
             END IF
          END DO
       END DO
       IF (TALLY > 1) THEN
          N_VIOLATIONS(I) = N_VIOLATIONS(I) + 1
       END IF
    END DO
    PROB = EXP(DBLE(N_VIOLATIONS))
    PROB = PROB / SUM(PROB)
  END SUBROUTINE GENERATE_PROBABILITIES

  SUBROUTINE SWAP(Q, Y, N1, N2)
    IMPLICIT NONE
    INTEGER :: Q(:), Y(:,:), N1, N2, IX_NEW_1(3), IX_NEW_2(3)
    INTEGER :: INDEX_OLD_1, INDEX_OLD_2, INDEX_NEW_1, INDEX_NEW_2
    CALL INDEX_MAP(Y(N1,:), INDEX_OLD_1)
    CALL INDEX_MAP(Y(N2,:), INDEX_OLD_2)
    Q(INDEX_OLD_1) = 0
    Q(INDEX_OLD_2) = 0
    IX_NEW_1 = Y(N1,:)
    IX_NEW_1(3) = Y(N2,3)
    IX_NEW_2 = Y(N2,:)
    IX_NEW_2(3) = Y(N1,3)
    CALL INDEX_MAP(IX_NEW_1, INDEX_NEW_1)
    CALL INDEX_MAP(IX_NEW_2, INDEX_NEW_2)
    Q(INDEX_NEW_1) = 1
    Q(INDEX_NEW_2) = 1
    Y(N1,:) = IX_NEW_1
    Y(N2,:) = IX_NEW_2
  END SUBROUTINE SWAP

  SUBROUTINE SAMPLE_MULTINOMIAL(PROBS, S)
    IMPLICIT NONE
    REAL(KIND=DBLE_PREC) :: PROBS(:), CUMSUM(SIZE(PROBS)-1), UNIFORM
    INTEGER :: N, J, S
    N = SIZE(PROBS)-1
    CUMSUM(1) = PROBS(1)
    DO J = 2,N
       CUMSUM(J) = PROBS(J) + CUMSUM(J-1)
    END DO
    CALL RANDOM_NUMBER(UNIFORM)
    S = 1
    DO J = 1,N
       IF (UNIFORM .LE. CUMSUM(J)) THEN
          EXIT
       ELSE
          S = S + 1
       END IF
    END DO
  END SUBROUTINE SAMPLE_MULTINOMIAL

  SUBROUTINE GENERATE_PAIR(PROBS, N1, N2)
    IMPLICIT NONE
    REAL(KIND=DBLE_PREC) :: PROBS(:)
    INTEGER :: N1, N2

    CALL SAMPLE_MULTINOMIAL(PROBS, N1)
    DO
       CALL SAMPLE_MULTINOMIAL(PROBS, N2)
       IF (N2 .NE. N1) EXIT
    END DO
  END SUBROUTINE GENERATE_PAIR

END MODULE SIMULATED_ANNEALING

!SUBROUTINE TEST_MAKE_BOARD(X,Y,M,N,BOARD)
!  USE SIMULATED_ANNEALING
!  IMPLICIT NONE
!  INTEGER :: M, N, X(M,3), Y(N,3), BOARD(9,9)
!  CALL MAKE_BOARD(X,Y,BOARD)
!END SUBROUTINE TEST_MAKE_BOARD

!SUBROUTINE TEST_GENERATE_PROBABILITIES(X, Y, M, N, PROB)
!  USE SIMULATED_ANNEALING
!  IMPLICIT NONE
!  INTEGER :: M, N, X(M,3), Y(N,3)
!  REAL(KIND=DBLE_PREC) :: PROB(N)
!  CALL GENERATE_PROBABILITIES(X, Y, PROB)
!END SUBROUTINE

SUBROUTINE SUDOKU_BY_SIMULATED_ANNEALING(P, Q, N, C, N_CONSTRAINTS, &
     X, M, Y, N_MISSING, N_VIOLATIONS, LOSS_HX, MAX_ITER, K, TEMP, ITER)

  USE CONSTANTS
  USE SIMULATED_ANNEALING
  IMPLICIT NONE
  INTEGER :: N, N_CONSTRAINTS, N_MISSING, I, INDEX, N1, N2, MAX_ITER, ITER, M
  INTEGER :: P(N), Q(N), C(N_CONSTRAINTS,N), Y(N_MISSING, 3), LOSS_HX(MAX_ITER), X(M,3)
  INTEGER :: LAST_LOSS, CURRENT_LOSS, N_VIOLATIONS, COOL_TIMER, COOL_ALARM, EPOCH, EPOCH_INC
  INTEGER :: RUN
  REAL(KIND=DBLE_PREC) :: UNIFORM, PR, K, TEMP, T0, PROBS(N_MISSING)

  COOL_TIMER = 1
  T0 = TEMP
  EPOCH_INC = 100000
  EPOCH = EPOCH_INC
  COOL_ALARM = 50
  Q = P

  DO I = 1,N_MISSING
     CALL INDEX_MAP(Y(I,:), INDEX)
     Q(INDEX) = 1
  END DO

  CALL LOSS(Q, C, LAST_LOSS)
  LOSS_HX(1) = LAST_LOSS
  RUN = 0
  DO I = 2,MAX_ITER
     CALL GENERATE_PROBABILITIES(X, Y, PROBS)
!     CALL RANDOM_NUMBER(UNIFORM)
!     N1 = INT(DBLE(N_MISSING)*UNIFORM)+1
!     DO
!        CALL RANDOM_NUMBER(UNIFORM)
!        N2 = INT(DBLE(N_MISSING)*UNIFORM)+1
!        IF (N2 .NE. N1) EXIT
!     END DO

     CALL GENERATE_PAIR(PROBS, N1, N2)

     CALL SWAP(Q, Y, N1, N2)
     CALL LOSS(Q, C, N_VIOLATIONS)
     IF (N_VIOLATIONS .GE. LAST_LOSS) THEN
        PR = EXP( DBLE(LAST_LOSS - N_VIOLATIONS) / (K*TEMP))
        CALL RANDOM_NUMBER(UNIFORM)
        IF (UNIFORM > PR) THEN
           CALL SWAP(Q, Y, N2, N1)
        ELSE
           LAST_LOSS = N_VIOLATIONS
        END IF
     ELSE
        LAST_LOSS = N_VIOLATIONS
     END IF
     IF (LOSS_HX(I-1) .EQ. LAST_LOSS) THEN
        RUN = RUN + 1
     ELSE
        RUN = 0
     END IF
     LOSS_HX(I) = LAST_LOSS
     COOL_TIMER = COOL_TIMER + 1
     IF (COOL_TIMER .EQ. COOL_ALARM) THEN
        COOL_TIMER = 1
        TEMP = 0.99 * TEMP
     END IF
     
     IF (N_VIOLATIONS .EQ. 0) EXIT

     IF (I .EQ. EPOCH) THEN
        TEMP = T0
        EPOCH = EPOCH + EPOCH_INC
     END IF
  END DO
  
  ITER = MIN(I, MAX_ITER)


END SUBROUTINE SUDOKU_BY_SIMULATED_ANNEALING