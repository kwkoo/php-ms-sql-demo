Hello World

<?php
  $serverName = $_ENV["DB_SERVER"];
  $connectionInfo = array("UID"=>$_ENV["DB_USER"],
	                      "PWD"=>$_ENV["DB_PASSWORD"],
	                      "Database"=>$_ENV["DATABASE"]);
  $conn = sqlsrv_connect($serverName, $connectionInfo);
  if ($conn == false) {
		echo "Unable to connect.</br>";
		die(print_r(sqlsrv_errors(), true));
	}
	$tsql = "SELECT ProductName FROM Products";
	$stmt = sqlsrv_query($conn, $tsql);
	if ($stmt == false) {
		echo "Error executing query.</br>";
		die(print_r(sqlsrv_errors(), true));
	}
	echo '<table border="1">';
	while ($row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_NUMERIC)) {
		echo "<tr><td>".$row[0]."</td></tr>"."\n";
	}
	echo "</table>";

	sqlsrv_free_stmt($stmt);
	sqlsrv_close($conn);
?>