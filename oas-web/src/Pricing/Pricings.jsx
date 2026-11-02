import { gql, useMutation, useQuery } from "@apollo/client"
import { TableCell, TableContainer, TableHead, TableRow, Table, TableBody, IconButton } from "@mui/material"
import { get } from "lodash"
import EditIcon from '@mui/icons-material/Edit';
import { Link, useOutletContext } from "react-router-dom";
import DeleteIcon from '@mui/icons-material/Delete';
import { StyledTableRow } from '../utils/util';
import { useEffect } from "react";
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';


export const Pricings = () => {
  const { setTitle } = useOutletContext();

  useEffect(() => {
    setTitle("Pricings");
  }, [])

  const { data, refetch } = useQuery(gql`
    query {
      pricings {
        id,
        name
      }
    }
  `)
  useEffect(() => {
    refetch()
  }, [])

  const [deleteMutation, {error}] = useMutation(gql`
    mutation ($id: Int!) {
      pricing_delete(id: $id) {
        success
      }
    }
  `)
  const onDelete = (id) => async () => {
    try {
      await deleteMutation({
        variables: {
          id: id
        }
      })
    } catch (error) {
      console.error(error);
    }
    refetch()
  }

  return <TableContainer>
    <Table>
      <TableHead>
        <TableRow>
          <TableCell>Id</TableCell>
          <TableCell>Name</TableCell>
          <TableCell>Actions</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {get(data, "pricings", []).map((pricing, i) => {
          const thisError = (error?.graphQLErrors || []).find(({id}) => id === pricing.id)?.message
          return [<TableRow key={i}>
            <TableCell>{pricing.id}</TableCell>
            <TableCell>{pricing.name}</TableCell>
            <TableCell>
              <IconButton title={`Got to instances of ${pricing.name}`} component={Link} to={`/pricing-instances/${pricing.id}`}>
                <FitnessCenterIcon />
              </IconButton>
              <IconButton title={`Edit ${pricing.name}`} component={Link} to={`/pricing/${pricing.id}`}>
                <EditIcon />
              </IconButton>
              {<IconButton title={`Delete ${pricing.name}`} onClick={onDelete(pricing.id)}>
                <DeleteIcon sx={{ color: 'red' }} />
              </IconButton>}
            </TableCell>
          </TableRow>,
          ...(thisError ? [<StyledTableRow className="errors" key={`row-error-${pricing.id}`}>
            <TableCell colSpan={3}>
               Delete failed: {thisError}
            </TableCell>
          </StyledTableRow>] : [])
          ]
        })}
      </TableBody>
    </Table>
  </TableContainer>
}
