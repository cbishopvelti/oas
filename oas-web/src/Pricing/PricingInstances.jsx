import { useParams } from "react-router-dom";
import { gql, useMutation, useQuery } from "@apollo/client"
import { TableCell, TableContainer, TableHead, TableRow, Table, TableBody, IconButton } from "@mui/material"
import { get } from "lodash"
import EditIcon from '@mui/icons-material/Edit';
import { Link } from "react-router-dom";
import DeleteIcon from '@mui/icons-material/Delete';
import { StyledTableRow } from '../utils/util';
import { useEffect } from "react";
import { useOutletContext } from "react-router-dom";



export const PricingInstances = () => {
  let { pricing_id } = useParams();
  const { setTitle } = useOutletContext();
  if (pricing_id) {
    pricing_id = parseInt(pricing_id);
  }

  useEffect(() => {
    setTitle("Pricing Instances");
  }, [])

  const { data, refetch } = useQuery(gql`
    query($pricing_id: Int) {
      pricing_instances (pricing_id: $pricing_id) {
        id,
        name
      }
    }
  `, {
    variables: {
      pricing_id
    }
  })
  useEffect(() => {
    refetch()
  }, [])

  const [deleteMutation, {error}] = useMutation(gql`
    mutation ($id: Int!) {
      pricing_instance_delete(id: $id) {
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
        {get(data, "pricing_instances", []).map((pricing_instance, i) => {
          const thisError = (error?.graphQLErrors || []).find(({id}) => id === pricing_instance.id)?.message
          return [<TableRow key={i}>
            <TableCell>{pricing_instance.id}</TableCell>
            <TableCell>{pricing_instance.name}</TableCell>
            <TableCell>
              <IconButton title={`Edit ${pricing_instance.name}`} component={Link} to={`/pricing-instance/${pricing_instance.id}`}>
                <EditIcon />
              </IconButton>
              {<IconButton title={`Delete ${pricing_instance.name}`} onClick={onDelete(pricing_instance.id)}>
                <DeleteIcon sx={{ color: 'red' }} />
              </IconButton>}
            </TableCell>
          </TableRow>,
          ...(thisError ? [<StyledTableRow className="errors" key={`row-error-${pricing_instance.id}`}>
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
