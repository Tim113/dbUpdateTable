#' dbSyncTable and Create
#'
#' A convenience function to use create to directly sync a model to the database
#'
#' @param con A database connection
#' @param model A \code{data.table} model - by convention is prefaced with \code{model_}
#' @param ... Convenience way to pass optional arguments to pass to Create
#'
#' @export

dbSyncTable = function(con, model, ...) {
  str_name = deparse(substitute(model))
  create_query = create(model = model, name = str_name, ...)
  DBI::dbGetQuery(con, create_query)
  TRUE
}

#' Create
#'
#' Create a query to which when executed will create keyed data.tables in a MySQL database
#'
#' @param model A \code{data.table} model - by convention is prefaced with \code{model_}
#' @param verbose Boolean to control printing of created statement
#' @param ... Carry parameters forward from dbSyncTable
#'
#' @include get_sql_type.R
#' @include utils.R
#' @export

create = function(model, verbose = TRUE, ...) {

  # Handle dots
  dots = list(...)
  # Carry debug flag forward from dbSyncTable
  if("verbose" %in% names(dots)) verbose = dots[["verbose"]]

  # Carry model name forward from dbSyncTable
  str_name = deparse(substitute(model))
  if("name" %in% names(dots)) str_name = dots[["name"]]

  # Check is model name conforms to name that can be parsed, and db inserted
  if (!stringr::str_detect(str_name, "^model_")) {
    stop("Model object name must be prefixed with 'model_', e.g. 'model_People'")
  }
  # Get table name to insert
  str_table_name = stringr::str_extract(str_name, "(?<=model_)[[:alpha:]]+")

  # Get variables
  # Parse data.table to creat CREATE TABLE query
  str_structure = vapply(model, class, FUN.VALUE = character(1))
  dt_structure = data.table(colname = names(str_structure), type = str_structure)
  dt_structure[, type := get_sql_type(type)]
  # Push table structure into string query format
  str_variables = dt_structure %>% get_query_variables()

  # Get the primary key
  str_pk = model %>% get_pk()

  # Construct insert statement
  statement = "CREATE TABLE IF NOT EXISTS %(table_name)s ( %(variables)s PRIMARY KEY(%(primary_key)s) );"
  params = list(table_name  = str_table_name,
                variables   = str_variables,
                primary_key = str_pk)
  # Insert constructe values
  statement = statement %format% params

  if(verbose) {
    console_log = statement
    console_log = stringr::str_replace(console_log, " \\( ", "\n\\(\n  ")
    console_log = stringr::str_replace_all(console_log, ", (?=[A-Z].+PRIMARY)", ",\n  ")
    console_log = stringr::str_replace(console_log, ", PRIMARY KEY", ",\n  PRIMARY KEY")
    console_log = stringr::str_replace(console_log, " \\);", "\n\\);")
    writeLines(console_log)
  }

  # return
  statement
}

# Global variables for data.table column names made in dt_structure
if(getRversion() >= "2.15.1")  utils::globalVariables(c("colname", "type"))

get_query_variables = function(dt, sep = " ", spacer = "") {
  if(sep == "\n") spacer = "  "
  str = dt[, paste0(spacer, colname, " ", type, ",", collapse = sep)]
  if(str == " ,") stop("No columns in model")
  str
}

get_pk = function(dt, spacer = " ") {
  str_pk = paste0(data.table::key(dt), collapse = ", ")
  # str_pk = sprintf(statement_key, str_pk)
  if (str_pk == "") stop("Model has no primary key")
  str_pk
}
