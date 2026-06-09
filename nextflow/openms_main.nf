#!/usr/bin/env nextflow

Channel
    .fromPath("/crex/proj/uppmax2026-1-94/metabolomics/mzMLData/*.mzML")
    .set { mzMLFiles }

Channel
    .value(file("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/FeatureFinder.ini"))
    .set { featureFinderIni }

Channel
    .value(file("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/featureAlignment.ini"))
    .set { alignmentIni }

Channel
    .value(file("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/featureLinker.ini"))
    .set { linkerIni }


process process_masstrace_detection_pos_OpenMS {

    input:
    file mzmlFile from mzMLFiles
    each file(settingFile) from featureFinderIni

    output:
    file "${mzmlFile.baseName}.featureXML" into alignmentProcess

    script:
    """
    FeatureFinderMetabo \
        -in ${mzmlFile} \
        -out ${mzmlFile.baseName}.featureXML \
        -ini ${settingFile}
    """
}


process process_masstrace_alignment_pos_OpenMS {

    memory '12 GB'

    input:
    file featureFiles from alignmentProcess.collect()
    each file(settingFile) from alignmentIni

    output:
    file "out/*.featureXML" into LinkerProcess

    script:

    def inputFiles = featureFiles.collect{ it.name }.join(' ')
    def outputFiles = featureFiles.collect{ "out/${it.name}" }.join(' ')

    """
    mkdir out

    MapAlignerPoseClustering \
        -in ${inputFiles} \
        -out ${outputFiles} \
        -ini ${settingFile}
    """
}


process process_masstrace_linker_pos_OpenMS {

    memory '12 GB'

    input:
    file alignedFiles from LinkerProcess.collect()
    each file(settingFile) from linkerIni

    output:
    file "Aggregated.consensusXML" into textExport

    script:

    def inputFiles = alignedFiles.collect{ it.name }.join(' ')

    """
    FeatureLinkerUnlabeledQT \
        -in ${inputFiles} \
        -out Aggregated.consensusXML \
        -ini ${settingFile}
    """
}


process process_masstrace_exporter_pos_OpenMS {

    publishDir "results", mode: "copy"

    input:
    file consensusFile from textExport

    output:
    file "Aggregated_clean.csv" into out

    script:
    """
    TextExporter \
        -in ${consensusFile} \
        -out Aggregated.csv

    /usr/bin/readOpenMS.r \
        input=Aggregated.csv \
        output=Aggregated_clean.csv
    """
}
