AUTOMAKE_OPTIONS = subdir-objects

bin_PROGRAMS = read_C_from_log read_S_from_log get_MO_energy contribMO get_NTO_coef overlapMO
 
contribMO_SOURCES = ../modules/alerts.f90\
                    ../modules/line_preprocess.f90\
                    ../modules/constants.f90\
                    ../modules/matrix.f90\
                    ../modules/matrix_print.f90\
                    ../modules/manage_gaussian.f90\
                    contribMO.f90
contribMO_LDFLAGS = @LIBS@

overlapMO_SOURCES = ../modules/alerts.f90\
                    ../modules/line_preprocess.f90\
                    ../modules/constants.f90\
                    ../modules/verbosity.f90\
                    ../modules/matrix.f90\
                    ../modules/matrix_print.f90\
                    ../modules/manage_gaussian.f90\
                    overlapMO.f90
overlapMO_LDFLAGS = @LIBS@

get_NTO_coef_SOURCES = ../modules/alerts.f90\
                      ../modules/line_preprocess.f90\
                      ../modules/constants.f90\
                      ../modules/structure_types.f90\
                      ../modules/manage_gaussian.f90\
                      get_NTO_coef.f90
get_NTO_coef_LDFLAGS = @LIBS@

get_MO_energy_SOURCES = ../modules/alerts.f90\
                        ../modules/line_preprocess.f90\
                        ../modules/constants.f90\
                        ../modules/manage_gaussian.f90\
                        get_MO_energy.f90
get_MO_energy_LDFLAGS = @LIBS@

read_S_from_log_SOURCES = ../modules/line_preprocess.f90 \
                          read_S_from_log.f90

read_C_from_log_SOURCES = ../modules/line_preprocess.f90 \
                          read_C_from_log.f90


CLEANFILES =*.mod 



